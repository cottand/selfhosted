// modified original from https://github.com/watsonian/seaweedfs-nomad
job "seaweedfs" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    operator = "distinct_hosts"
    value    = true
  }

  group "master" {
    migrate {
      min_healthy_time = "1m"
    }
    constraint {
      attribute = "${meta.docker_privileged}"
      value     = true
    }
    network {
      # cannot be bridge because master uses port it to self-identify
      mode = "host"

      port "http" {
        static       = 9333
        host_network = "vpn"
      }

      port "grpc" {
        static       = 19333
        host_network = "vpn"
      }
      port "metrics" {
        host_network = "vpn"
      }
    }

    task "seaweedfs-master" {
      driver = "docker"

      config {
        image = "chrislusf/seaweedfs:3.51"

        args = [
          "-logtostderr",
          "master",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          //   "-mdir=/data",
          "-mdir=.",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          # no replication
          "-defaultReplication=000",
          "-metricsPort=${NOMAD_PORT_metrics}",
          # 1GB max volume size
          # lower=more volumes per box (easier replication)
          # higher=less splitting of large files
          "-volumeSizeLimitMB=1000",
        ]

        // volumes = [
        // "config:/config"
        // ]

        ports = ["http", "grpc", "metrics"]

        privileged = true
      }
      service {
        provider = "nomad"
        name     = "seaweedfs-master-metrics"
        port     = "metrics"
        tags     = ["metrics"]
      }
      service {
        provider = "nomad"
        name     = "seaweedfs-master-http"
        port     = "http"
        check {
          name     = "healthz"
          port     = "http"
          type     = "http"
          path     = "/cluster/healthz"
          interval = "20s"
          timeout  = "5s"
          check_restart {
            limit           = 3
            grace           = "10s"
            ignore_warnings = false
          }
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`seaweed.vps.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }

      service {
        provider = "nomad"
        name     = "seaweedfs-master-grpc"
        port     = "grpc"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "grpc"
          interval = "20s"
          timeout  = "2s"
        }
      }
      resources {
        cpu    = 100
        memory = 80
      }
    }
  }

  group "filer" {
    // to make sure there is a single filer instance
    constraint {
      attribute = "${meta.box}"
      value     = "elvis"
    }
    migrate {
      min_healthy_time = "1m"
    }
    network {
      mode = "host"

      port "http" {
        static       = 8888
        host_network = "vpn"
      }

      port "grpc" {
        static       = 18888
        host_network = "vpn"
      }
      port "metrics" {
        host_network = "vpn"
      }
      port "webdav" {
        static       = 17777
        host_network = "vpn"
      }
    }
    volume "seaweedfs-filer" {
      type      = "host"
      read_only = false
      source    = "seaweedfs-filer"
    }
    task "seaweedfs-filer" {
      // lifecycle {
      //   hook    = "poststart"
      //   sidecar = true
      // }
      service {
        name     = "seaweedfs-filer-http"
        port     = "http"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "http"
          interval = "20s"
          timeout  = "2s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`seaweed-filer.vps.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
      service {
        name     = "seaweedfs-filer-grpc"
        port     = "grpc"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "grpc"
          interval = "20s"
          timeout  = "2s"
        }
      }
      service {
        name     = "seaweedfs-webdav"
        port     = "webdav"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          port     = "webdav"
          interval = "20s"
          timeout  = "2s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.webdav.rule=Host(`webdav.vps.dcotta.eu`)",
          "traefik.http.routers.webdav.entrypoints=websecure",
          "traefik.http.routers.webdav.tls=true",
          "traefik.http.routers.webdav.tls.certresolver=lets-encrypt",
          "traefik.http.routers.webdav.middlewares=vpn-whitelist@file",
        ]
      }
      service {
        provider = "nomad"
        name     = "seaweedfs-filer-metrics"
        port     = "metrics"
        tags     = ["metrics"]
      }
      volume_mount {
        volume      = "seaweedfs-filer"
        destination = "/data"
        read_only   = false
      }
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:3.51"
        ports = ["http", "grpc", "metrics", "webdav"]
        args = [
          "-logtostderr",
          "filer",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-master=${SEAWEEDFS_MASTER_IP_http}:${SEAWEEDFS_MASTER_PORT_http}.${SEAWEEDFS_MASTER_PORT_grpc}",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-metricsPort=${NOMAD_PORT_metrics}",
          "-webdav",
          "-webdav.collection=",
          "-webdav.replication=010",
          "-webdav.port=${NOMAD_PORT_webdav}",

        ]
        // TODO:
        //         -webdav
        //     	whether to start webdav gateway
        //   -webdav.cacheCapacityMB int
        //     	local cache capacity in MB
        //   -webdav.cacheDir string
        //     	local cache directory for file chunks (default "/tmp")
        //   -webdav.cert.file string
        //     	path to the TLS certificate file
        //   -webdav.collection string
        //     	collection to create the files
        //   -webdav.disk string
        //     	[hdd|ssd|<tag>] hard drive or solid state drive or any tag
        //   -webdav.filer.path string
        //     	use this remote path from filer server (default "/")
        //   -webdav.key.file string
        //     	path to the TLS private key file
        //   -webdav.port int
        //     	webdav server http listen port (default 7333)
        //   -webdav.replication string
        //     	replication to create the files
      }

      template {
        destination = "/etc/seaweedfs/filer.toml"
        change_mode = "restart"
        data        = <<-EOF
        # A sample TOML config file for SeaweedFS filer store
# Put this file to one of the location, with descending priority
#    ./filer.toml
#    $HOME/.seaweedfs/filer.toml
#    /etc/seaweedfs/filer.toml

# Customizable filer server options
[filer.options]
# with http DELETE, by default the filer would check whether a folder is empty.
# recursive_delete will delete all sub folders and files, similar to "rm -Rf"
recursive_delete = false

[leveldb2]
# local on disk, mostly for simple single-machine setup, fairly scalable
# faster than previous leveldb, recommended.
enabled = true
dir = "/data"                    # directory to store level db files

[sqlite]
# local on disk, similar to leveldb
enabled = false
dbFile = "./filer.db"                # sqlite db file

[postgres2]
enabled = false
createTable = """
  CREATE TABLE IF NOT EXISTS "%s" (
    dirhash   BIGINT,
    name      VARCHAR(65535),
    directory VARCHAR(65535),
    meta      bytea,
    PRIMARY KEY (dirhash, name)
  );
"""
hostname = "localhost"
port = 5432
username = "postgres"
password = ""
database = "postgres"          # create or use an existing database
schema = ""
sslmode = "disable"
connection_max_idle = 100
connection_max_open = 100
connection_max_lifetime_seconds = 0
# if insert/upsert failing, you can disable upsert or update query syntax to match your RDBMS syntax:
enableUpsert = true
upsertQuery = """UPSERT INTO "%[1]s" (dirhash,name,directory,meta) VALUES($1,$2,$3,$4)"""
        EOF
      }
      template {
        destination = "config/.env"
        env         = true
        data        = <<-EOF
{{ range $i, $s := nomadService "seaweedfs-master-http" }}
{{- if eq $i 0 -}}
SEAWEEDFS_MASTER_IP_http={{ .Address }}
SEAWEEDFS_MASTER_PORT_http={{ .Port }}
{{- end -}}
{{ end }}
{{ range $i, $s := nomadService "seaweedfs-master-grpc" }}
{{- if eq $i 0 -}}
SEAWEEDFS_MASTER_IP_grpc={{ .Address }}
SEAWEEDFS_MASTER_PORT_grpc={{ .Port }}
{{- end -}}
{{ end }}
EOF
      }
    }
  }
}