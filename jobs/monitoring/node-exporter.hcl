job "node-exporter" {
  type = "system"
  group "node-exporter" {
    network {
      mode = "bridge"
      port "metrics" {
        host_network = "wg-mesh"
      }
    }

    task "node-exporter" {
      driver = "docker"

      config {
        image = "quay.io/prometheus/node-exporter:latest"
        args = [
          "--path.rootfs=/host",
          "--web.listen-address=:${NOMAD_PORT_metrics}",
        ]
        pid_mode = "host"

        volumes = ["/:/host:ro,rslave"]
        ports   = ["metrics"]
      }

      resources {
        cpu    = 256
        memory = 128
      }
      service {
        provider = "nomad"
        name     = "node-exporter"
        port     = "metrics"
        tags     = ["metrics"]
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}