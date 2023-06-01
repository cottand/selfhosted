variable "port" {
  type = number
  default = 8888
}

locals {
  grpcPort = var.port + 10000
}

job "seaweedfs-filer" {
  datacenters = ["dc1"]
  type = "service"

  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "filer" {
    network {
      mode = "host"

      port "http" {
        static = var.port
        to = var.port
      }

      port "grpc" {
        static = local.grpcPort
        to = local.grpcPort
      }
    }

    volume "seaweedfs-filer" {
        type      = "host"
        read_only = false
        source    = "seaweedfs-filer"
    }

    service {
      tags = ["http"]
      name = "seaweedfs-filer"
      port = "http"
    }

    service {
      tags = ["grpc"]
      name = "seaweedfs-filer"
      port = "grpc"
    }

    task "filer" {
      driver = "docker"

      template {
        destination = "config/.env"
        env = true
        data = <<-EOF
{{ range $i, $s := service "http.seaweedfs-master" }}
{{- if eq $i 0 -}}
SEAWEEDFS_MASTER_IP_http={{ .Address }}
SEAWEEDFS_MASTER_PORT_http={{ .Port }}
{{- end -}}
{{ end }}
{{ range $i, $s := service "grpc.seaweedfs-master" }}
{{- if eq $i 0 -}}
SEAWEEDFS_MASTER_IP_grpc={{ .Address }}
SEAWEEDFS_MASTER_PORT_grpc={{ .Port }}
{{- end -}}
{{ end }}
EOF
      }

      config {
        image = "chrislusf/seaweedfs"

        args = [
          "-logtostderr",
          "filer",
          "-ip=${NOMAD_IP_http}",
          "-ip.bind=0.0.0.0",
          "-master=${SEAWEEDFS_MASTER_IP_http}:${SEAWEEDFS_MASTER_PORT_http}.${SEAWEEDFS_MASTER_PORT_grpc}",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}"
        ]

        ports = ["http", "grpc"]
      }
    }
  }
}