job "lemmy-alex" {
  update {
    max_parallel = 1
    stagger      = "10s"
  }
  datacenters = ["dc1"]
  type        = "service"
  group "lemmy-alex" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
        to           = 3000
      }
    }

    task "lemmy-alex" {
      driver = "docker"

      config {
        image = "ghcr.io/sheodox/alexandrite:latest"
        ports = ["http"]
      }
      env {
        # see https://github.com/sheodox/alexandrite/blob/main/.env.example
        ALEXANDRITE_DEFAULT_INSTANCE="r.dcotta.eu"
        ALEXANDRITE_FORCE_INSTANCE="r.dcotta.eu"
      }

      service {
        name     = "lemmy-alex"
        provider = "nomad"
        port     = "http"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 3
            grace           = "30s"
            ignore_warnings = false
          }
        }
        tags = [
          "traefik.enable=true",
          # for some reason only when there is a longer hostname this works
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`r.dcotta.eu`) || Host(`alex.r.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure_public,websecure,web_public,web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
        ]
      }
      resources {
        cpu    = 90
        memory = 90
      }
    }
  }
}