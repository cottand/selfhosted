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
      mode = "host"

      port "http" {
        host_network = "vpn"
      }

      port "grpc" {
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
          "-port.grpc=${NOMAD_PORT_grpc}"
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
            grace           = "120s"
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
    }
  }
}