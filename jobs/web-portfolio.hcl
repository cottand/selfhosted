variable "tag" {
  type    = string
  default = "latest"
}

job "web-portfolio" {
  priority    = 50

  update {
    max_parallel = 1
    auto_revert  = true
    auto_promote = true
    canary       = 1
  }

  group "web-portfolio" {
    count = 3
    network {
      mode = "bridge"
      port "http" {
        to           = "80"
        host_network = "wg-mesh"
      }
    }
    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/cottand/web-portfolio:${var.tag}"
        ports = ["http"]
      }

      service {
        name     = "web-portfolio"
        provider = "nomad"
        check {
          name     = "alive"
          port     = "http"
          type     = "http"
          path     = "/"
          interval = "20s"
          timeout  = "5s"
          check_restart {
            limit           = 3
            grace           = "5s"
            ignore_warnings = false
          }
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`nico.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web, web_public, websecure, websecure_public",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt"
        ]
        port = "http"
      }
      resources {
        cpu    = 70
        memory = 60
      }
      template {
        destination = "config/.env"
        change_mode = "restart"
        env         = true
        data        = <<-EOF
{{ range nomadService "tempo-otlp-grpc" }}
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://{{ .Address }}:{{ .Port }}
OTEL_SERVICE_NAME="web-portfolio"
{{ end }}
EOF
      }
    }
  }
}