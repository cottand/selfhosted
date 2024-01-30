job "traefik" {
  group "traefik" {
    network {
      mode = "bridge"
      // port "dns-mesh" {
      //   // static = 53
      // }
      port "http-ui" {
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
        host_network = "wg-mesh"
      }
    }
    volume "traefik-cert" {
      type            = "csi"
      read_only       = false
      source          = "traefik-cert"
      access_mode     = "multi-node-single-writer"
      attachment_mode = "file-system"
    }
    service {
      name     = "traefik-metrics"
      provider = "nomad"
      port     = "metrics"
      tags = ["metrics"]
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
      config {
        image = "traefik:3.0.0-beta5"
        # needs to be in host wireguard network so that it can reach other VPN members
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik-dynamic.toml:/etc/traefik/dynamic/traefik-dynamic.toml",
        ]
      }
      constraint {
        attribute = "${meta.box}"
        value     = "miki"
      }

      template {
        data        = <<EOF
# [tcp.middlewares.vpn-whitelist.IPWhiteList]
#   sourcerange = [
#       '10.8.0.1/24', # VPN clients
#       '10.10.0.1/16', # WG mesh
#       '10.2.0.1/16', # VPN guests
#       '127.1.0.0/24', # VPN clients
#       '172.26.64.18/20', # containers
#       '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
#       '138.201.153.245', # miki's public contabo IP (will be origin when using sshuttle or VPN guest)
#   ]
[http.middlewares]
    # Middleware that only allows requests after the authentication with credentials specified in usersFile
    [http.middlewares.auth.basicauth]
        users = [
          # see https://doc.traefik.io/traefik/middlewares/http/basicauth/
          {{ with nomadVar "nomad/jobs/traefik" -}}
          "{{ .basicAuth_cottand }}"
          {{- end }}
        ]
    # Middleware that only allows requests from inside the VPN
    # https://doc.traefik.io/traefik/middlewares/http/ipwhitelist/
    [http.middlewares.vpn-whitelist.IPAllowList]
        sourcerange = [
            '10.8.0.1/24', # VPN clients
            '10.10.0.1/16', # WG mesh
            '10.2.0.1/16', # VPN guests
            '127.1.0.0/24', # VPN clients
            '172.26.64.18/20', # containers
            '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
            '138.201.153.245', # miki's public contabo IP (will be origin when using sshuttle or VPN guest)
        ]
    [http.middlewares.mesh-whitelist.IPAllowList]
        sourcerange = [
            '10.10.0.1/16', # WG mesh
            '127.1.0.0/24', # VPN clients
            '172.26.64.18/20', # containers
            '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
        ]
    [http.middlewares.replace-enc.replacePathRegex]
      regex = "/___enc_/(.*)"
      replacement = ""
# Nomad terminates TLS, so we let traefik just forward TCP
[tcp.routers]
  [tcp.routers.nomad]
    rule = "HostSNI( `nomad.vps.dcotta.eu` ) || HostSNI( `nomad.traefik` )"
    service = "nomad"
    entrypoints= "web,websecure"
    tls.passthrough = true
#    tls = true
#    tls.certresolver= "lets-encrypt"
#     middlewares = "vpn-whitelist@file"
[tcp.services]
  [tcp.services.nomad.loadBalancer]
    [[tcp.services.nomad.loadBalancer.servers]]
      address = "miki.mesh.dcotta.eu:4646"
        # TODO [3] add other servers for load balancing
EOF
        destination = "local/traefik-dynamic.toml"
        change_mode = "signal"
      }

      template {
        data        = <<EOF
[entryPoints]
  [entryPoints.dns]
        address = ":{{ env "NOMAD_PORT_dns_mesh" }}/udp"


  [entrypoints.web]
    address = ":{{ env "NOMAD_PORT_http_mesh" }}"
    #  [entryPoints.web.http.redirections.entryPoint]
    #    to = "websecure"
    #    scheme = "https"
  [entryPoints.websecure]
    address = ":{{ env "NOMAD_PORT_https_mesh" }}"


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
    address = "https://miki.mesh.dcotta.eu:4646"
    # TODO make vault with secret work
    tls.insecureSkipVerify = true
    token = "{{ env "NOMAD_TOKEN" }}"

[providers.file]
  filename = "/etc/traefik/dynamic/traefik-dynamic.toml"

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
      identity { env = true }
      resources {
        cpu    = 256
        memory = 256
      }
    }
  }





  group "follower" {
    network {
      mode = "bridge"
      port "dns-mesh" {
        static = 53
      }
      port "http-ui" {
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
        host_network = "wg-mesh"
      }
    }
    volume "traefik-cert" {
      type            = "csi"
      read_only       = true
      source          = "traefik-cert"
      access_mode     = "multi-node-single-writer"
      attachment_mode = "file-system"
    }
    service {
      name     = "traefik-metrics"
      provider = "nomad"
      port     = "metrics"
      tags = ["metrics"]
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
        interval = "20s"
        timeout  = "2s"
      }
    }

    count = 2
    task "traefik" {
      driver = "docker"
      volume_mount {
        volume      = "traefik-cert"
        destination = "/etc/traefik-cert"
        read_only   = true
      }
      config {
        image = "traefik:3.0.0-beta5"
        # needs to be in host wireguard network so that it can reach other VPN members
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik-dynamic.toml:/etc/traefik/dynamic/traefik-dynamic.toml",
        ]
      }
      constraint {
        attribute = "${meta.box}"
        operator = "!="
        value     = "miki"
      }
    # serve on all datacenter servers
    # TODO use nomad tag
    constraint {
      attribute = "${meta.box}"
      operator  = "regexp"
      # We need static IPs for master servers
      value = "^cosmo|maco$"
    }

      template {
        data        = <<EOF
[http.middlewares]
    # Middleware that only allows requests after the authentication with credentials specified in usersFile
    [http.middlewares.auth.basicauth]
        users = [
          # see https://doc.traefik.io/traefik/middlewares/http/basicauth/
          {{ with nomadVar "nomad/jobs/traefik" -}}
          "{{ .basicAuth_cottand }}"
          {{- end }}
        ]
    # Middleware that only allows requests from inside the VPN
    # https://doc.traefik.io/traefik/middlewares/http/ipwhitelist/
    [http.middlewares.vpn-whitelist.IPAllowList]
        sourcerange = [
            '10.8.0.1/24', # VPN clients
            '10.10.0.1/16', # WG mesh
            '10.2.0.1/16', # VPN guests
            '127.1.0.0/24', # VPN clients
            '172.26.64.18/20', # containers
            '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
            '138.201.153.245', # miki's public contabo IP (will be origin when using sshuttle or VPN guest)
        ]
    [http.middlewares.mesh-whitelist.IPAllowList]
        sourcerange = [
            '10.10.0.1/16', # WG mesh
            '127.1.0.0/24', # VPN clients
            '172.26.64.18/20', # containers
            '185.216.203.147', # comsmo's public contabo IP (will be origin when using sshuttle)
        ]
    [http.middlewares.replace-enc.replacePathRegex]
      regex = "/___enc_/(.*)"
      replacement = ""
# Nomad terminates TLS, so we let traefik just forward TCP
[tcp.routers]
  [tcp.routers.nomad]
    rule = "HostSNI( `nomad.vps.dcotta.eu` ) || HostSNI( `nomad.traefik` )"
    service = "nomad"
    entrypoints= "web,websecure"
    tls.passthrough = true
[tcp.services]
  [tcp.services.nomad.loadBalancer]
    [[tcp.services.nomad.loadBalancer.servers]]
      address = "maco.mesh.dcotta.eu:4646"
        # TODO [3] add other servers for load balancing
EOF
        destination = "local/traefik-dynamic.toml"
        change_mode = "signal"
      }

      template {
        data        = <<EOF
[entryPoints]
  [entryPoints.dns]
        address = ":{{ env "NOMAD_PORT_dns_mesh" }}/udp"


  [entrypoints.web]
    address = ":{{ env "NOMAD_PORT_http_mesh" }}"
  [entryPoints.websecure]
    address = ":{{ env "NOMAD_PORT_https_mesh" }}"


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
  # bogus settings
  caServer = "https://acme-staging-v02.api.letsencrypt.org/directory/FAKE"
  certificatesDuration = 21600


  [certificatesResolvers.lets-encrypt.acme.httpChallenge]
    # let's encrypt has to be able to reach on this entrypoint for cert
   entryPoint = "web_public"

[providers.nomad]
  refreshInterval = "5s"
  exposedByDefault = false

  defaultRule = "Host(`{{"{{ .Name }}"}}.traefik`)"

  [providers.nomad.endpoint]
    address = "https://cosmo.mesh.dcotta.eu:4646"
    # TODO make vault with secret work
    tls.insecureSkipVerify = true
    token = "{{ env "NOMAD_TOKEN" }}"

[providers.file]
  filename = "/etc/traefik/dynamic/traefik-dynamic.toml"

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
      identity { env = true }
      resources {
        cpu    = 256
        memory = 256
      }
    }
  }
}