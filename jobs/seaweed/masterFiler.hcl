// modified original from https://github.com/watsonian/seaweedfs-nomad
variable "seaweedfs_version" {
  type    = string
  default = "3.57"
}
variable "master_port_http" {
  type    = number
  default = 9333
}
variable "master_port_grpc" {
  type    = number
  default = 19333
}

job "seaweedfs" {
  datacenters = ["*"]
  type        = "service"

  group "master" {
    count = 3
    constraint {
      attribute = "${meta.box}"
      operator  = "regexp"
      # We need static IPs for master servers
      value = "^miki|cosmo|maco$"
    }
    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }
    update {
      max_parallel = 1
      stagger      = "5m"
      canary       = 0
    }
    migrate {
      min_healthy_time = "2m"
    }
    restart {
      interval = "10m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    constraint {
      attribute = "${meta.docker_privileged}"
      value     = true
    }
    network {
      # cannot be bridge because master uses port it to self-identify
      mode = "host"

      port "http" {
        static       = var.master_port_http
        host_network = "wg-mesh"
      }

      port "grpc" {
        static       = var.master_port_grpc
        host_network = "wg-mesh"
      }
      port "metrics" {
        host_network = "wg-mesh"
      }
    }

    task "seaweedfs-master" {
      driver = "docker"

      config {
        image = "chrislusf/seaweedfs:${var.seaweedfs_version}"

        args = [
          "-logtostderr",
          "master",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          //   "-mdir=/data",
          "-mdir=${NOMAD_TASK_DIR}/master",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-defaultReplication=200",
          "-metricsPort=${NOMAD_PORT_metrics}",
          # peers must match constraint above
          "-peers=10.10.4.1:${NOMAD_PORT_http},10.10.2.1:${NOMAD_PORT_http},10.10.0.1:${NOMAD_PORT_http}",
          # 1GB max volume size
          # lower=more volumes per box (easier replication)
          # higher=less splitting of large files
          "-volumeSizeLimitMB=1000",
        ]

        ports = ["http", "grpc", "metrics"]
        volumes = [ "local/master.toml:/etc/seaweedfs/master.toml"]

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
          "seaweedfs-master.name=${node.meta.name}",
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web,websecure",
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
      template {
        destination = "local/master.toml"
        data        = <<-EOF
        [master.maintenance]
        # periodically run these scripts are the same as running them from 'weed shell'
        scripts = """
          lock

          volume.configure.replication -collectionPattern immich-pictures -replication 200
          ec.encode -fullPercent=95 -quietFor=1h -collection="immich-pictures"

          ec.rebuild -force
          ec.balance -force

          volume.deleteEmpty -quietFor=24h -force
          volume.balance -force
          volume.fix.replication
          s3.clean.uploads -timeAgo=24h
          unlock
        """
        # Do this in weed shell to grow buckets by 2 volumes when they are full, with replicatoin 010
        # fs.configure -locationPrefix=/buckets/ -replication=010 -volumeGrowthCount=2 -apply


        sleep_minutes = 16          # sleep minutes between each script execution

        [master.sequencer]
        type = "raft"     # Choose [raft|snowflake] type for storing the file id sequence
        # when sequencer.type = snowflake, the snowflake id must be different from other masters
        sequencer_snowflake_id = 0     # any number between 1~1023


        # create this number of logical volumes if no more writable volumes
        # count_x means how many copies of data.
        # e.g.:
        #   000 has only one copy, copy_1
        #   010 and 001 has two copies, copy_2
        #   011 has only 3 copies, copy_3
        # [master.volume_growth]
        # copy_1 = 7                # create 1 x 7 = 7 actual volumes
        # copy_2 = 2                # create 2 x 6 = 12 actual volumes
        # copy_3 = 3                # create 3 x 3 = 9 actual volumes
        # copy_other = 1            # create n x 1 = n actual volumes
        EOF

      }
    }
  }

  group "filer" {
    restart {
      interval = "10m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    // to make sure there is a single filer instance
    constraint {
      attribute = "${meta.box}"
      value     = "cosmo"
    }
    migrate {
      min_healthy_time = "1m"
    }
    network {
      mode = "bridge"
      dns {
        servers = [
          "10.10.0.1",
          "10.10.2.1",
          "10.10.1.1",
        ]
      }

      port "http" {
        static       = 8888
        host_network = "wg-mesh"
      }
      port "grpc" {
        static       = 18888
        host_network = "wg-mesh"
      }
      port "metrics" {
        host_network = "wg-mesh"
      }
      port "webdav" {
        static       = 17777
        host_network = "wg-mesh"
      }
      // port "webdav-vpn" {
      //   static       = 17777
      //   host_network = "vpn"
      // }
      port "s3" {
        host_network = "wg-mesh"
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
      service { # TODO implement http healthcheck https://github.com/seaweedfs/seaweedfs/pull/4899/files
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
          // "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`seaweed-filer.vps.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web,websecure",
          // "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          // "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=mesh-whitelist@file",
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
      }
      service {
        provider = "nomad"
        name     = "seaweedfs-filer-metrics"
        port     = "metrics"
        tags     = ["metrics"]
      }
      service {
        provider = "nomad"
        name     = "seaweedfs-filer-s3"
        port     = "s3"
        // tags = [
        //   "traefik.enable=true",
        //   "traefik.http.routers.${NOMAD_TASK_NAME}-s3.entrypoints=web,websecure",
        //   "traefik.http.routers.${NOMAD_TASK_NAME}-s3.middlewares=vpn-whitelist@file",
        // ]
      }
      volume_mount {
        volume      = "seaweedfs-filer"
        destination = "/data"
        read_only   = false
      }
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:${var.seaweedfs_version}"
        ports = ["http", "grpc", "metrics", "webdav"]
        args = [
          "-logtostderr",
          "filer",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          // "-master=${SEAWEEDFS_MASTER_IP_http}:${SEAWEEDFS_MASTER_PORT_http}.${SEAWEEDFS_MASTER_PORT_grpc}",
          "-master=seaweedfs-master-http.nomad:${var.master_port_http}.${var.master_port_grpc}",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-metricsPort=${NOMAD_PORT_metrics}",
          "-webdav",
          "-webdav.collection=",
          "-webdav.replication=020",
          "-webdav.port=${NOMAD_PORT_webdav}",
          "-s3",
          "-s3.port=${NOMAD_PORT_s3}",
          "-s3.allowEmptyFolder=false",
        ]
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
recursive_delete = true

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
      resources {
        cpu    = 220
        memory = 521
      }
    }
  }
}