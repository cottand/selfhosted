job "grafana" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 1
  group "grafana" {
    count = 1
    volume "grafana" {
      type            = "csi"
      read_only       = false
      source          = "grafana-swfs"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }
    network {
      mode = "bridge"
      dns {
        servers = ["10.8.0.1"]
      }
      port "http" {
        to           = 3000
        host_network = "vpn"
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:9.4.7"
        ports = ["http"]
      }
      user = "root:root"
      env = {
        "GF_AUTH_BASIC_ENABLED"         = false
        "GF_AUTH_DISABLE_LOGIN_FORM"    = false
        "GF_AUTH_ANONYMOUS_ENABLED"     = true
        "GF_AUTH_ANONYMOUS_ORG_ROLE"    = "Viewer"
        "GF_SERVER_ROOT_URL"            = "https://web.vps.dcotta.eu/grafana"
        "GF_SERVER_SERVE_FROM_SUB_PATH" = true
        "GF_SECURITY_ALLOW_EMBEDDING"   = true
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
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.middlewares.${NOMAD_TASK_NAME}-stripprefix.stripprefix.prefixes=/${NOMAD_TASK_NAME}",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`web.vps.dcotta.eu`) && PathPrefix(`/${NOMAD_TASK_NAME}`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=${NOMAD_TASK_NAME}-stripprefix,vpn-whitelist@file",
        ]
      }
    }
  }
}
