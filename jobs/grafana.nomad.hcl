job "grafana" {
    datacenters = ["dc1"]
    type        = "service"
    group "grafana" {
        count = 1

        network {
            mode = "bridge"
            port "http" {
                to = 3000
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
            driver  = "docker"
            config {
                image = "grafana/grafana:9.4.7"
                ports= ["http"]
            }
            service {
                name = "grafana"
                provider = "nomad"
                port = "http"

                tags = [
                    "traefik.enable=true",
                    "traefik.http.middlewares.grafana-stripprefix.stripprefix.prefixes=/grafana",
                    "traefik.http.routers.grafana.rule=Host(`web.vps.dcotta.eu`) && PathPrefix(`/grafana`)",
                    "traefik.http.routers.grafana.entrypoints=websecure",
                    "traefik.http.routers.grafana.tls=true",
                    "traefik.http.routers.grafana.tls.certresolver=lets-encrypt",
                    "traefik.http.routers.grafana.middlewares=grafana-stripprefix,vpn-whitelist@file",
                ]
            }
        }
    }
}
