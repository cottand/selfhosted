job "whoami" {
  datacenters = ["*"]
  priority    = 1
  group "whoami" {
    constraint {
      attribute = "${meta.box}"
      value     = "ari"
    }
    network {
      mode = "bridge"
      port "http" {
        to           = "80"
        host_network = "wg-mesh"
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

      service {
        name     = "whoami"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.whoami.rule=PathPrefix(`/whoami`)",
          "traefik.http.middlewares.whoami-stripprefix.stripprefix.prefixes=/whoami",
          "traefik.http.routers.whoami.middlewares=whoami-stripprefix",
          "traefik.http.routers.whoami.entrypoints=websecure, websecure_public",
          "traefik.http.routers.whoami.tls=true",
          "traefik.http.routers.whoami.tls.certresolver=lets-encrypt"
        ]
        port = "http"
      }
    }
  }
}