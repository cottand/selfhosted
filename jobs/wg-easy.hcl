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
        static       = 51821
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
        image        = "weejewel/wg-easy:latest"
        privileged   = true
        ports        = ["http", "wg"]
        cap_add      = ["NET_ADMIN", "SYS_MODULE"]
        network_mode = "host"
      }
      env {
        WG_HOST                 = "vpn.dcotta.eu"
        WG_PORT                 = 51820
        WG_PERSISTENT_KEEPALIVE = "25"
        WG_DEFAULT_ADDRESS      = "10.2.0.x"
        WG_DEFAULT_DNS          = "138.201.153.245" # miki public IP
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