// modified original from https://github.com/watsonian/seaweedfs-nomad
job "seaweedfs" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    operator = "distinct_hosts"
    value    = true
  }

  group "master" {
    constraint {
      attribute = "${meta.docker_privileged}"
      value     = true
    }
    network {
      # cannot be bridge because master uses port it to self-identify
      mode = "host"

      port "http" {
        static = 9333
        host_network = "vpn"
      }

      port "grpc" {
        static = 19333
        host_network = "vpn"
      }
    }

    // volume "seaweedfs-master" {
    //     type      = "host"
    //     read_only = false
    //     source    = "seaweedfs-master"
    // }


    task "seaweed" {
      driver = "docker"

      //   volume_mount {
      //     volume      = "seaweedfs-master"
      //     destination = "/data"
      //     read_only   = false
      //   }

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
          "-defaultReplication=010"
        ]

        // volumes = [
        // "config:/config"
        // ]

        ports = ["http", "grpc"]

        privileged = true
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
            grace           = "60s"
            ignore_warnings = false
          }
        }
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
    network {
      mode = "host"

      port "http" {
        host_network = "vpn"
      }

      port "grpc" {
        host_network = "vpn"
      }
    }
    volume "seaweedfs-filer" {
      type      = "host"
      read_only = false
      source    = "seaweedfs-filer"
    }
    task "seaweed" {
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
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:3.51"
        ports = ["http", "grpc"]
        args = [
          "-logtostderr",
          "filer",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-master=${SEAWEEDFS_MASTER_IP_http}:${SEAWEEDFS_MASTER_PORT_http}.${SEAWEEDFS_MASTER_PORT_grpc}",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}"
        ]
      }

      template {
        destination = "local/filer.toml.bu"
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
dir = "./filerldb2"                    # directory to store level db files

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