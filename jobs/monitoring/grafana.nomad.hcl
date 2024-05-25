job "grafana" {
  datacenters = ["*"]
  type        = "service"
  priority    = 1
  group "grafana" {
    count = 1
    network {
      mode = "bridge"
      dns {
        servers = [
          "10.10.0.1",
          "10.10.2.1",
          "10.10.4.1",
          "10.10.1.1",
        ]
      }
      port "healthz" { to = -1 }
    }

    restart {
      attempts = 4
      interval = "10m"
      delay    = "15s"
      mode     = "delay"
    }

    service {
      name = "grafana"
      port = "3000"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "roach-db"
              local_bind_port  = 5432
            }
            upstreams {
              destination_name = "mimir-http"
              local_bind_port  = 8000
            }
            upstreams {
              destination_name = "tempo-http"
              local_bind_port  = 8001
            }
            upstreams {
              destination_name = "tempo-otlp-grpc-mesh"
              local_bind_port  = 19199
            }
          }
        }
      }

      check {
        expose   = true
        name     = "healthz"
        port     = "healthz"
        type     = "http"
        path     = "/api/health"
        interval = "20s"
        timeout  = "5s"
        check_restart {
          limit           = 3
          grace           = "30s"
          ignore_warnings = false
        }
        task = "grafana"
        // address_mode = "driver"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        // "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file",

        "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web, websecure",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls=true",
      ]

    }
    task "grafana" {
      vault {
        env = true
      }
      driver = "docker"
      config {
        image = "grafana/grafana:10.4.1"
        ports = ["http"]
        args  = ["--config", "/local/config.ini"]
      }
      user = "root:root"
      env = {
        "GF_AUTH_BASIC_ENABLED"         = false
        "GF_AUTH_DISABLE_LOGIN_FORM"    = false
        "GF_AUTH_ANONYMOUS_ENABLED"     = true
        "GF_AUTH_ANONYMOUS_ORG_ROLE"    = "Viewer"
        "GF_SERVER_ROOT_URL"            = "http://grafana.traefik"
        "GF_SERVER_SERVE_FROM_SUB_PATH" = true
        "GF_SECURITY_ALLOW_EMBEDDING"   = true
        "GF_FEATURE_TOGGLES_ENABLE"     = "traceToMetrics logsExploreTableVisualisation"
      }

      template {
        change_mode = "restart"
        destination = "local/config.ini"

        data = <<EOH
          [database]
            type = "postgres"
            host = "localhost:5432"
            user = "grafana"
            ssl_mode = "verify-full"
            ssl_sni = "roach-db.traefik"
            servert_cert_name = "cockroachdb-2023-mar-20.roach-db.traefik"
            ca_cert_path = "/secrets/ca.crt"
            client_key_path = "/secrets/client.grafana.key"
            client_cert_path = "/secrets/client.grafana.crt"
        EOH
      }
      template {
        destination = "/secrets/client.grafana.key"
        change_mode = "restart"
        data        = <<EOF
{{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.key}}{{end}}
        EOF
        perms       = "0600"
      }
      template {
        destination = "/secrets/client.grafana.crt"
        change_mode = "restart"
        data        = <<EOF
{{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.chain}}{{end}}
        EOF
        perms       = "0600"
      }
      template {
        destination = "/secrets/ca.crt"
        change_mode = "restart"
        data        = <<EOF
{{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.ca}}{{end}}
        EOF
        perms       = "0600"
      }
    }
  }
}
