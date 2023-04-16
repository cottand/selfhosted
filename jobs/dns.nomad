#dns:
#image: spx01/blocky
#container_name: dns
#restart: unless-stopped
## Optional the instance hostname for logging purpose
#hostname: dns
#networks:
#metrics: # on port 4000/tcp
#wg:
#ipv4_address: 10.8.1.3
#ports:
#- "53:53/tcp"
#- "53:53/udp"
#volumes:
## Optional to synchronize the log timestamp with host
#- /etc/localtime:/etc/localtime:ro
#- ./blocky-dns/config.yml:/app/config.yml
#labels:
#traefik.enable: true
#traefik.udp.services.dns.loadbalancer.server.port: 53
#traefik.tcp.services.dns.loadbalancer.server.port: 53
##      traefik.http.routers.whoami.middlewares: whoami-stripprefix,auth@file
#traefik.udp.routers.dns.entrypoints: dns-udp
#traefik.tcp.routers.dns.entrypoints: dns-tcp
##      traefik.tcp.routers.whoami.tls: true

job "dns" {
  datacenters = ["dc1"]
  group "blocky-dns" {
    network {
      port "dns" {
        static       = 53
        host_network = "vpn"
      }
      port "metrics" {
        to           = 4000
        host_network = "vpn"
      }
    }


    service {
      name = "dns-metrics"
      provider = "nomad"
      port     = "metrics"
    }
    service {
      name     = "dns"
      provider = "nomad"
      port     = "dns"
      check {
        name     = "alive"
        type     = "tcp"
        port     = "metrics"
        interval = "20s"
        timeout  = "2s"
      }
    }
    task "blocy-dns" {
      driver = "docker"
      config {
        image   = "spx01/blocky"
        volumes = [
          "local/config.yml:/app/config.yml",
        ]
        ports = ["dns", "metrics"]
      }
      env = {
        "environment" = "TZ=Europe/Berlin"
      }
      constraint {
        attribute = "${meta.box}"
        value     = "cosmo"
      }
      resources {
        cpu    = 100
        memory = 128
      }
      template {
        data        = <<EOF
port: {{ env "NOMAD_PORT_dns"  }}
httpPort: {{ env "NOMAD_PORT_metrics" }}
upstream:
  default:
    # DNS over TCP https://blog.uncensoreddns.org/dns-servers/
    - 91.239.100.100:843
    - 9.9.9.9
    - 1.1.1.1
#    - https://dns.digitale-gesellschaft.ch/dns-query

customDNS:
  customTTL: 5m
  rewrite:
    vps.dcotta.eu: cosmo.vps
    web.vps.dcotta.eu: cosmo.vps
  mapping:
    # address of traefik + wg network. Requests to this IP will hit the traefik proxy which will route
    # containers appropriately
    cosmo.vps: 10.8.0.1
    maco.vps: 10.8.0.5

blocking:
  blackLists:
    ads:
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
      - https://raw.githubusercontent.com/kboghdady/youTube_ads_4_pi-hole/master/black.list
  clientGroupsBlock:
    default:
      - ads

prometheus:
  enable: true
EOF
        destination = "local/config.yml"
      }
    }
  }
}