job "cosmo" {

  group "wg-easy" {
    network {
      port "http" {
        # has to be static because we are doing host network
        static = 51821
      }
      port "wireguard" {
        static = 51820
      }
    }

    volume "wireguard" {
      type = "host"
      read_only = "false"
      source = "wireguard"

    }

    service {
      name = "wg-easy"

      provider = "nomad"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "20s"
        timeout  = "2s"
      }
    }

    task "wg-easy" {
      driver = "docker"

      # must run on cosmo
      constraint {
        attribute = "${meta.box}"
        value = "cosmo"
      }

      config {
        image        = "weejewel/wg-easy:7"
        network_mode = "host"

        env {
          WG_HOST        = "vps.dcotta.eu"
          WG_DEFAULT_DNS = "10.8.1.3"
        }
        volume_mount {
          volume      = "wireguard"
          destination = "/etc/wireguard"
          read_only   = false
        }

        capabilities = ["NET_ADMIN", "SYS_MODULE"]
      }
    }
  }
}