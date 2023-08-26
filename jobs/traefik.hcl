job "traefik" {
  datacenters = ["dc1"]

  group "traefik" {
    network {
      mode = "bridge"
      port "http-ui" {
        static       = 8080
        host_network = "vpn"
      }
      port "http" {
        static       = 80
        host_network = "vpn"
      }
      port "https" {
        static       = 443
        host_network = "vpn"
      }
      port "http-ui-mesh" {
        static       = 8080
        host_network = "wg-mesh"
      }
      port "http-mesh" {
        static       = 80
        host_network = "wg-mesh"
      }
      port "https-mesh" {
        static       = 443
        host_network = "wg-mesh"
      }
      port "http_public" {
        static = 80
        to     = 8000
      }
      port "https_public" {
        static = 443
        to     = 44300
      }
      port "metrics" {
        static       = 31934 # hardcoded so that prometheus can find it after restart
        host_network = "vpn"
      }
    }
    volume "traefik-cert" {
      type      = "host"
      read_only = false
      source    = "traefik-cert"
    }
    volume "traefik-basic-auth" {
      type      = "host"
      read_only = true
      source    = "traefik-basic-auth"
    }
    service {
      name     = "traefik-metrics"
      provider = "nomad"
      port     = "metrics"
      tags = [
        "metrics",
      ]
      check {
        name     = "alive"
        type     = "tcp"
        port     = "metrics"
        interval = "20s"
        timeout  = "2s"
      }
    }
    service {
      name     = "traefik"
      provider = "nomad"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.traefik_dash.entrypoints=web,websecure",
        "traefik.http.routers.traefik_dash.rule=Host(`traefik.vps.dcotta.eu`) || PathPrefix(`/dashboard`)",
        "traefik.http.routers.traefik_dash.tls=true",
        "traefik.http.routers.traefik_dash.tls.certResolver=lets-encrypt",
        "traefik.http.routers.traefik_dash.service=api@internal",
        // "traefik.http.routers.traefik_dash.middlewares=auth@file",
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
        "WG_HOST" = "web.vps.dcotta.eu"
      }
      volume_mount {
        volume      = "traefik-cert"
        destination = "/etc/traefik-cert"
        read_only   = false
      }
      volume_mount {
        volume      = "traefik-basic-auth"
        destination = "/etc/traefik-basic-auth"
        read_only   = true
      }

      config {
        image = "traefik:3.0.0-beta3"
        # needs to be in host wireguard network so that it can reach other VPN members
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik-dynamic.toml:/etc/traefik/dynamic/traefik-dynamic.toml",
        ]
      }
      constraint {
        attribute = "${meta.box}"
        value     = "cosmo"
      }

      template {
        data        = <<EOF
[http.middlewares]
    # Middleware that only allows requests after the authentication with credentials specified in usersFile
    [http.middlewares.auth.basicauth]
        usersFile = "/etc/traefik-basic-auth/users"
    # Middleware that only allows requests from inside the VPN
    # https://doc.traefik.io/traefik/middlewares/http/ipwhitelist/
    [http.middlewares.vpn-whitelist.IPAllowList]
        sourcerange = [
            '10.8.0.1/24', # VPN clients
            '10.10.0.1/16', # WG mesh
            '127.1.0.0/24', # VPN clients
            '172.26.64.18/20', # containers
            '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
        ]
    [http.middlewares.mesh-whitelist.IPAllowList]
        sourcerange = [
            '10.10.0.1/16', # WG mesh
            '127.1.0.0/24', # VPN clients
            '172.26.64.18/20', # containers
            '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
        ]
[http.routers]
  [http.routers.nomad]
    rule = "Host( `nomad.vps.dcotta.eu` ) || Host( `nomad.traefik` )"
    service = "nomad"
    entrypoints= "web,websecure"
#    tls = true
#    tls.certresolver= "lets-encrypt"
#    middlewares = "vpn-whitelist@file"
[http.services]
  [http.services.nomad.loadBalancer]
    [[http.services.nomad.loadBalancer.servers]]
      url = "http://10.8.0.1:4646/"
        # TODO [3] add other servers for load balancing
EOF
        destination = "local/traefik-dynamic.toml"
        change_mode = "signal"
      }

      template {
        data        = <<EOF
[entryPoints]
  [entryPoints.web]

    address = ":{{ env "NOMAD_PORT_http" }}"
    #  [entryPoints.web.http.redirections.entryPoint]
    #    to = "websecure"
    #    scheme = "https"
  [entryPoints.websecure]
    address = ":{{ env "NOMAD_PORT_https" }}"


  # redirects 8000 (in container) to 443
  [entryPoints.web_public]
    address = ":{{ env "NOMAD_PORT_http_public" }}"
    [entryPoints.web_public.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"
      
  [entryPoints.websecure_public]
    address = ":{{ env "NOMAD_PORT_https_public" }}"

    # redirects 44300 (in container) to 443
    [entryPoints.websecure_public.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"


  [entryPoints.metrics]
    address = ":{{ env "NOMAD_PORT_metrics" }}"

[metrics]
  [metrics.prometheus]
    addServicesLabels = true
    entryPoint = "metrics"

[api]
  dashboard = true
  insecure = true

[certificatesResolvers.lets-encrypt.acme]
  email = "nico@dcotta.eu"
  storage = "/etc/traefik-cert/acme.json"

  [certificatesResolvers.lets-encrypt.acme.httpChallenge]
    # let's encrypt has to be able to reach on this entrypoint for cert
   entryPoint = "web_public"

[providers.nomad]
  refreshInterval = "5s"
  exposedByDefault = false

  defaultRule = "Host(`{{"{{ .Name }}"}}.traefik`)"

  [providers.nomad.endpoint]
    address = "http://10.10.0.1:4646"


[providers.file]
  directory = "/etc/traefik/dynamic"

    {{ range nomadService "tempo-otlp-grpc" -}}
    [tracing]
        [tracing.openTelemetry]
        address = "{{ .Address }}:{{ .Port }}"
        insecure = true
            [tracing.openTelemetry.grpc]
    {{ end -}}

EOF
        change_mode = "restart"
        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 120
        memory = 128
      }
    }
  }
}