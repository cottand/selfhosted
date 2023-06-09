
job "web-portfolio" {
  datacenters = ["dc1"]
  priority    = 1
  group "web-portfolio" {
    count = 2
    network {
      mode = "bridge"
      port "http" {
        to           = "80"
        host_network = "vpn"
      }
    }
    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/cottand/web-portfolio:latest"
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
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
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