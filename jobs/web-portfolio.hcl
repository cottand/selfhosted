variable "tag" {
  type    = string
  default = "sha-2713046"
}

job "web-portfolio" {
  priority = 50

  update {
    max_parallel = 1
    auto_revert  = true
    auto_promote = true
    canary       = 1
  }

  group "web-portfolio" {
    count = 4
    network {
      mode = "bridge"
      port "http" {}
    }
    service {
      task = "web"
      connect {
        sidecar_service {}
      }
      name = "web-portfolio-c"
      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.connect=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.rule=Host(`nico.dcotta.eu`)",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web, web_public, websecure, websecure_public",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls.certresolver=lets-encrypt"
      ]
      port = "http"
    }
    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/cottand/web-portfolio:${var.tag}"
      }
        env {
          PORT = "${NOMAD_PORT_http}"
          HOST = "127.0.0.1"
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