job "miki-vpn" {
  group "wg-ui" {
    // must run on box with wg port exposed and vpn-guest.dcotta.eu DNS
    constraint {
      attribute = "${meta.box}"
      value     = "miki"
    }
    network {
      mode = "host"
      port "http" {
        host_network = "wg-mesh"
      }
      port "wg" {
        static = 51825
      }
    }

    task "wg-ui" {
      driver = "docker"
      config {
        image      = "embarkstudios/wireguard-ui:latest"
        privileged = true
        ports      = ["http", "wg"]
        cap_add =  ["NET_ADMIN", "SYS_MODULE" ]
      }
      env {
        // WG_HOST                 = "vpn-guest.dcotta.eu"
        // WG_PORT                 = 51820
        // WG_PERSISTENT_KEEPALIVE = "25"
        // WG_DEFAULT_ADDRESS      = "10.2.0.x"
        // WG_DEFAULT_DNS          = "10.10.4.1"
        WIREGUARD_UI_LISTEN_ADDRESS  = "0.0.0.0:${NOMAD_PORT_http}"
        WIREGUARD_UI_LOG_LEVEL       = "info"
        WIREGUARD_UI_DATA_DIR        = "/data"
        WIREGUARD_UI_WG_ENDPOINT     = "vpn-guest.dcotta.eu:51825"
        WIREGUARD_UI_CLIENT_IP_RANGE = "10.2.0.0/24"
        WIREGUARD_UI_WG_DNS          = "10.10.4.1"
        WIREGUARD_UI_NAT             = "true"
        WIREGUARD_UI_NAT_DEVICE      = "eth0"
        WIREGUARD_UI_WG_DEVICE_NAME  = "wg-guest"
      }
      resources {
        cpu    = 90
        memory = 90
      }
      service {
        name     = "vpn-wg-ui"
        provider = "nomad"
        port     = "http"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 3
            grace           = "30s"
            ignore_warnings = false
          }
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure,web",
        ]
      }
    }
  }
}