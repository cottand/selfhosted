job "vaultwarden" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 1

  group "vaultwarden" {
    restart {
      attempts = 4
      interval = "30m"
      delay    = "20s"
      mode     = "fail"
    }
    network {
      mode = "bridge"
      port "http" {
        host_network = "vpn"
      }
    }
    volume "vaultwarden" {
      type            = "csi"
      read_only       = false
      source          = "swfs-vaultwarden"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "vaultwarden" {
      driver = "docker"

      config {
        image = "vaultwarden/server:1.28.1"

        // volumes = [
        // "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        // ]

        ports = ["http"]

      }
      env = {
        "ROCKET_PORT" = "${NOMAD_PORT_http}"
      }
      volume_mount {
        volume      = "vaultwarden"
        destination = "/data"
        read_only   = false
      }

      service {

        name     = "vaultwarden"
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