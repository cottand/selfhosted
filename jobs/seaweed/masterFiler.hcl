// variable "port" {
//   type = number
//   default = 9333
// }

// locals {
//   grpcPort = var.port + 10000
// }

job "seaweedfs" {
  datacenters = ["dc1"]
  type = "service"

  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "master" {
    constraint {
        attribute = "${meta.docker_privileged}"
        value     = true
    }
    network {
      mode = "host"

      port "http" {
        // static = var.port
        // to = var.port
        host_network = "vpn"
      }

      port "grpc" {
        // static = local.grpcPort
        // to = local.grpcPort
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
        ]

        // volumes = [
            // "config:/config"
        // ]

        ports = ["http", "grpc"]

        privileged = true
      }
    service {
      provider = "nomad"
      name = "seaweedfs-master-http"
      port = "http"
    }

    service {
      provider = "nomad"
      name = "seaweedfs-master-grpc"
      port = "grpc"
    }
    }
  }

  
}