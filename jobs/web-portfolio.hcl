variable "docker_tag" {
  type    = string
  default = "latest"
}

job "web-portfolio" {
  datacenters = ["dc1"]
  priority    = 50

  update {
    max_parallel = 3
    auto_revert  = true
    auto_promote = true
    canary       = 1
  }

  group "web-portfolio" {
    count = 2
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
        image = "ghcr.io/cottand/web-portfolio:${var.docker_tag}"
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
        cpu    = 100
        memory = 60
      }
    }
  }
}