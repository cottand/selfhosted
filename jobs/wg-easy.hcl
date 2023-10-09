job "wg-easy" {
  group "wg-easy" {
    // must run on box with wg port exposed and vpn-guest.dcotta.eu DNS
    constraint {
      attribute = "${meta.box}"
      value     = "miki"
    }
    network {
      mode = "host"
      port "http" {
        to = 51821
        host_network = "wg-mesh"
      }
      port "wg" {
        static = 51820
      }
    }
    volume "wg-easy-conf" {
      type            = "csi"
      read_only       = false
      source          = "wg-easy-conf"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "wg-easy" {
      driver = "docker"
      config {
        image      = "weejewel/wg-easy:latest"
        privileged = true
        ports      = ["http", "wg"]
        cap_add    = ["NET_ADMIN", "SYS_MODULE"]
      }
      env {
        WG_HOST                 = "vpn.dcotta.eu"
        WG_PORT                 = 51820
        WG_PERSISTENT_KEEPALIVE = "25"
        WG_DEFAULT_ADDRESS      = "10.2.0.x"
        WG_DEFAULT_DNS          = "138.201.153.245" # miki public IP
        // WIREGUARD_UI_LISTEN_ADDRESS  = "0.0.0.0:${NOMAD_PORT_http}"
        // WIREGUARD_UI_LOG_LEVEL       = "info"
        // WIREGUARD_UI_DATA_DIR        = "/data"
        // WIREGUARD_UI_WG_ENDPOINT     = "vpn-guest.dcotta.eu:51825"
        // WIREGUARD_UI_CLIENT_IP_RANGE = "10.2.0.0/24"
        // WIREGUARD_UI_WG_DNS          = "10.10.4.1"
        // WIREGUARD_UI_NAT             = "true"
        // WIREGUARD_UI_NAT_DEVICE      = "eth0"
        // WIREGUARD_UI_WG_DEVICE_NAME  = "wg-guest"
      }
      volume_mount {
        volume      = "wg-easy-conf"
        destination = "/etc/wireguard"
        read_only   = false
      }
      resources {
        cpu    = 90
        memory = 90
      }
      service {
        name     = "wg-easy-ui"
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
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=mesh-whitelist@file",
        ]
      }
    }
  }
}