job "whoami" {
  datacenters = ["dc1"]

  group "whoami" {
    network {
      port "http" {
        to = "80"
#        static = "5678"
        host_network = "vpn"
      }
    }
    task "whoami" {
      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["http"]
        args  = [
         "--port=80",
        ]
      }

      service {
        name = "whoami"
        provider = "nomad"
        tags =  [
          "traefik.enable=true",
          "traefik.http.routers.whoami.rule=Host(`web.vps.dcotta.eu`) && PathPrefix(`/whoami`)",
          "traefik.http.middlewares.whoami-stripprefix.stripprefix.prefixes=/whoami",
          "traefik.http.routers.whoami.middlewares=whoami-stripprefix",
          "traefik.http.routers.whoami.entrypoints=websecure",
          "traefik.http.routers.whoami.tls=true",
          "traefik.http.routers.whoami.tls.certresolver=lets-encrypt"
        ]
        port = "http"
    }
    }
  }
}