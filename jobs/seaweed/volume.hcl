
// modified original from https://github.com/watsonian/seaweedfs-nomad
job "seaweedfs-volume" {
  datacenters = ["dc1"]
  type        = "system"


  constraint {
    attribute = "${meta.seaweedfs_volume}"
    value     = true
  }

  group "volumes" {
    network {
      mode = "host"

      port "http" {
        host_network = "vpn"
      }

      port "grpc" {
        host_network = "vpn"
      }

      port "metrics" {
        host_network = "vpn"
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
        name     = "seaweedfs-volume"
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
        name     = "seaweedfs-volume"
        port     = "grpc"
        provider = "nomad"
      }
      volume_mount {
        volume      = "seaweedfs-volume"
        destination = "/data"
        read_only   = false
      }

      config {
        image = "chrislusf/seaweedfs:3.51"

        args = [
          "-logtostderr",
          "volume",
          "-mserver=${SEAWEEDFS_MASTER_IP_http}:${SEAWEEDFS_MASTER_PORT_http}.${SEAWEEDFS_MASTER_PORT_grpc}",
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
        ]

        volumes = [
          "config:/config"
        ]

        ports = ["http", "grpc", "metrics"]

        privileged = true
      }
      template {
        destination = "config/.env"
        change_mode = "restart"
        env         = true
        data        = <<-EOF
_IGNORE=1
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