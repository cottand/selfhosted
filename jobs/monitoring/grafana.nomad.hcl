job "grafana" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 1
  group "grafana" {
    count = 1
    volume "grafana" {
      type      = "host"
      read_only = false
      source    = "grafana-cosmo"
    }
    // volume "grafana" {
    //   type            = "csi"
    //   read_only       = false
    //   source          = "grafana"
    //   access_mode     = "single-node-writer"
    //   attachment_mode = "file-system"
    // }
    network {
      mode = "bridge"
      dns {
        servers = [
          "10.10.0.1",
          "10.10.2.1",
          "10.10.1.1",
        ]
      }
      port "http" {
        to           = 3000
        host_network = "wg-mesh"
      }
    }

    restart {
      attempts = 4
      interval = "10m"
      delay    = "15s"
      mode     = "delay"
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:10.1.5"
        ports = ["http"]
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
      volume_mount {
        volume      = "grafana"
        destination = "/var/lib/grafana"
        read_only   = false
      }
      service {
        name     = "grafana"
        provider = "nomad"
        port     = "http"

        check {
          name     = "alive"
          port     = "http"
          type     = "http"
          path     = "/api/health"
          interval = "20s"
          timeout  = "5s"
          check_restart {
            limit           = 3
            grace           = "30s"
            ignore_warnings = false
          }
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
    }
  }
}
