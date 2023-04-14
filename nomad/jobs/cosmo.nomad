job "cosmo" {

  datacenters = ["dc1"]

  group "traefik" {
    network {
      mode = "host"
      port "http-ui" {
        static = 8080
        host_network = "vpn"
      }
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "db" {
        static = 5432
      }
      port "metrics" {}
    }
    volume "traefik-cert" {
      type      = "host"
      read_only = false
      source    = "traefik-cert"
    }
    service {
      name = "traefik"
      provider = "nomad"
      tags =  [
        "traefik.enable=true",
        "traefik.http.routers.traefik_https.rule=Host(`traefik.vps.dcotta.eu`)",
        "traefik.http.routers.traefik_https.entrypoints=web,websecure",
        "traefik.http.routers.traefik_https.tls=true",
        "traefik.http.routers.traefik_https.tls.certResolver=lets-encrypt",
        "traefik.http.routers.traefik_https.service=api@internal",
        "traefik.http.routers.traefik_https.middlewares=auth@file",
        #        "traefik.http.services.wg-easy.loadbalancer.server.port=${NOMAD_PORT_}"
      ]
      port = "http-ui"
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "20s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"
      env = {
        "WG_HOST"        = "web.vps.dcotta.eu"
        "WG_DEFAULT_DNS" = "10.8.1.3"
      }
      volume_mount {
        volume      = "traefik-cert"
        destination = "/etc/traefik-cert"
        read_only   = false
      }

      config {
        image        = "traefik:v3.0"
        # needs to be in host wireguard network so that it can reach other VPN members
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }
      constraint {
        attribute = "${meta.box}"
        value = "cosmo"
      }

      template {
        data = <<EOF
[entryPoints]
  [entryPoints.db]
    address = ":{{ env "NOMAD_PORT_db" }}"
  [entryPoints.web]
    address = ":{{ env "NOMAD_PORT_http" }}"
    [entryPoints.web.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"
#
  [entryPoints.websecure]
    address = ":{{ env "NOMAD_PORT_https" }}"
  [entryPoints.metrics]
    address = ":{{ env "NOMAD_PORT_metrics" }}"

[metrics]
  [metrics.prometheus]
    addServicesLabels = true
    entryPoint = "metrics"

[api]
  dashboard = true

[certificatesResolvers.lets-encrypt.acme]
  email = "nico@dcotta.eu"
  storage = "/etc/traefik-cert/acme.json"

  [certificatesResolvers.lets-encrypt.acme.httpChallenge]
    # let's encrypt has to be able to reach on this entrypoint for cert
    entryPoint = "web"

[providers.nomad]
  refreshInterval = "10s"
  exposedByDefault = false

  [providers.nomad.endpoint]
    address = "http://10.8.0.1:4646"


#[providers.file]
  # specified as docker secret, bound in compose file and under cosmo/secrets
#  directory = "/etc/traefik/dynamic"

EOF
        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 120
        memory = 128
      }
    }
  }
}