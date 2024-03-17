job "traefik" {
  group "traefik" {
    network {
      mode = "bridge"
      port "dns-mesh" {
        // static = 53
      }
      port "http-ui" {
        to = 8080
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
        host_network = "public"
      }
      port "https_public" {
        static = 443
        to     = 44300
        host_network = "public"
      }
      port "metrics" {
        static       = 31934 # hardcoded so that prometheus can find it after restart
        host_network = "wg-mesh"
      }
    }
    volume "traefik" {
      type            = "host"
      read_only       = false
      source          = "traefik"
    }
    service {
      name     = "traefik-metrics"
      // provider = "nomad"
      port     = "metrics"
      tags     = ["metrics"]
      // check {
      //   name     = "alive"
      //   type     = "tcp"
      //   port     = "metrics"
      //   interval = "20s"
      //   timeout  = "2s"
      // }
    }
    service {
      name     = "traefik"
      // provider = "nomad"
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
      // check {
      //   name     = "alive"
      //   type     = "tcp"
      //   interval = "20s"
      //   timeout  = "2s"
      // }
      connect {
        sidecar_service {}
      }
    }
    service {
      name = "traefik-ingress"
      port = "http-mesh"
      task = "traefik"

      connect {
        native = true
      }
    }
    task "traefik" {
      identity {
        env = true
      }
      driver = "docker"
      env = {
        "WG_HOST" = "web.vps.dcotta.eu"
      }
      volume_mount {
        volume      = "traefik"
        destination = "/etc/traefik-cert"
        read_only   = false
      }
      config {
        image = "traefik:3.0.0-rc3"
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
  #storage = "/etc/traefik/"

  [certificatesResolvers.lets-encrypt.acme.httpChallenge]
    # let's encrypt has to be able to reach on this entrypoint for cert
   entryPoint = "web_public"

[providers.consulCatalog]
  # The service name below should match the nomad/consul service above
  # and is used for intentions in consul
  servicename="traefik-ingress"
  refreshInterval = "10s"
  exposedByDefault = false
  connectAware = true
  connectByDefault = true
  #prefix="traefik"

  #endpoint.address = "10.10.4.1:8501"
  endpoint.tls.insecureSkipVerify = true # TODO add SAN for this IP!
  endpoint.datacenter = "dc1"
  #endpoint.scheme = "http" # TODO change

  defaultRule = "Host(`{{"{{ .Name }}"}}.traefik`)"
  


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

    #[tracing]
    #    [tracing.openTelemetry]
    #    address = "{{ .Address }}:{{ .Port }}"
    #    insecure = true
    #        [tracing.openTelemetry.grpc]
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