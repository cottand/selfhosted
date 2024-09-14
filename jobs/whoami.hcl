job "whoami" {
  affinity {
    attribute = "${meta.controlPlane}"
    value     = "true"
    weight    = -70
  }
  group "whoami" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        host_network = "ts-mesh"
      }
    }
      service {
        name     = "whoami"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.whoami.rule=PathPrefix(`/whoami`)",
          "traefik.http.middlewares.whoami-stripprefix.stripprefix.prefixes=/whoami",
          "traefik.http.routers.whoami.middlewares=whoami-stripprefix",
          "traefik.http.routers.whoami.entrypoints=websecure, web",
        ]
        port = "http"
        connect {
          sidecar_service {
            proxy {
              upstreams {
                destination_name = "web-portfolio-c"
                local_bind_port  = 8001
              }
            }
          }
        }
      }
    task "whoami" {
      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["http"]
        args = [
          "--port=${NOMAD_PORT_http}",
        ]
      }
    }
  }
}