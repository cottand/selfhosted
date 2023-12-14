
// modified original from https://github.com/watsonian/seaweedfs-nomad
job "seaweedfs-volume" {
  datacenters = ["*"]
  type        = "system"

  update {
    max_parallel = 1
    stagger      = "60s"
  }
  constraint {
    attribute = "${meta.seaweedfs_volume}"
    value     = true
  }

  group "volumes" {
    restart {
      interval = "10m"
      attempts = 6
      delay    = "15s"
      mode     = "delay"
    }

    network {
      dns {
        servers = ["10.10.0.1", "10.10.1.1", "10.10.2.1", "10.10.4.1" ]
      }
      mode = "host"

      port "http" {
        host_network = "wg-mesh"
        static       = 9876
      }

      port "grpc" {
        host_network = "wg-mesh"
        # gRPC needs to be http + 1_000
        static = 19876
      }

      port "metrics" {
        host_network = "wg-mesh"
      }
    }

    volume "seaweedfs-volume" {
      type      = "host"
      read_only = false
      source    = "seaweedfs-volume"
    }


    task "seaweed" {
      driver = "docker"

      service {
        name     = "seaweedfs-volume-http"
        port     = "http"
        provider = "nomad"
        check {
          name     = "healthz"
          port     = "http"
          type     = "http"
          path     = "/status"
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
        name     = "seaweedfs-volume-metrics"
        port     = "metrics"
        provider = "nomad"
        tags     = ["metrics"]
      }

      service {
        name     = "seaweedfs-volume-grpc"
        port     = "grpc"
        provider = "nomad"
      }
      volume_mount {
        volume      = "seaweedfs-volume"
        destination = "/data"
        read_only   = false
      }

      resources {
        cpu        = 200
        memory     = 512
        memory_max = 1500
      }
      config {
        image = "chrislusf/seaweedfs:3.57"

        args = [
          "-logtostderr",
          "volume",
          # from master DNS and well-known ports so that job is not reset
          "-mserver=seaweedfs-master-http.nomad:9333.19333",
          //   "-dir=/data/${node.unique.name}",
          "-dir=/data",
          "-max=0",
          "-dataCenter=${node.datacenter}",
          "-rack=${node.unique.name}",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-metricsPort=${NOMAD_PORT_metrics}",
          # min free disk space. Low disk space will mark all volumes as ReadOnly.
          "-minFreeSpace=10GiB",
          # maximum numbers of volumes. If set to zero, the limit will be auto configured as free disk space divided by volume size. default "8"
          "-max=0",
        ]

        volumes = [
          "config:/config"
        ]

        ports = ["http", "grpc", "metrics"]

        privileged = true
      }
    }
  }
}