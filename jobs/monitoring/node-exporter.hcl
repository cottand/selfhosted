job "node-exporter" {
  type = "system"

  node_pool = "all"
  group "node-exporter" {
    network {
      mode = "bridge"
      port "metrics" {
        host_network = "ts"
        static = 59219
      }
    }

    service {
      name = "node-exporter-metrics"
      port = "metrics"
      check {
        name     = "metrics"
        port     = "metrics"
        type     = "http"
        path     = "/metrics"
        interval = "10s"
        timeout  = "3s"
      }
      meta {
        metrics_port = "${NOMAD_HOST_PORT_metrics}"
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
        cpu    = 100
        memory = 60
      }
    }
  }
}