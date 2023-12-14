job "vaultwarden" {
  datacenters = ["*"]
  type        = "service"

  group "vaultwarden" {
    restart {
      attempts = 4
      interval = "30m"
      delay    = "20s"
      mode     = "fail"
    }
    network {
      mode = "bridge"
      port "http" {
        host_network = "vpn"
      }
      port "ws" {
        host_network = "vpn"
      }
    }
    volume "vaultwarden" {
      type            = "csi"
      read_only       = false
      source          = "swfs-vaultwarden"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "vaultwarden" {
      driver = "docker"

      config {
        image = "vaultwarden/server:1.28.1"

        // volumes = [
        // "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        // ]

        ports = ["http"]

      }
      env = {
        "ROCKET_PORT" = "${NOMAD_PORT_http}"
        //   "WEBSOCKET_ENABLED"= true;
        //   "WEBSOCKET_ADDRESS"= "0.0.0.0";
        //   "WEBSOCKET_PORT"= ${NOMAD_PORT_ws};
        //   "SIGNUPS_VERIFY"= true;
        #    ADMIN_TOKEN"= (import /etc/nixos/secret/bitwarden.nix).ADMIN_TOKEN;
        "DOMAIN" = "https://warden.vps.dcotta.eu" ;
        #    YUBICO_CLIENT_ID"= (import /etc/nixos/secret/bitwarden.nix).YUBICO_CLIENT_ID;
        #    YUBICO_SECRET_KEY"= (import /etc/nixos/secret/bitwarden.nix).YUBICO_SECRET_KEY;
        "YUBICO_SERVER" = "https://api.yubico.com/wsapi/2.0/verify" ;
      }
      volume_mount {
        volume      = "vaultwarden"
        destination = "/data"
        read_only   = false
      }

      service {

        name     = "vaultwarden"
        provider = "nomad"
        port     = "http"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`warden.vps.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
      service {
        name = "vaultwarden-ws"

        provider = "nomad"
        port     = "http"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`warden.vps.dcotta.eu/ws`)  && Path(`/notifications/hub`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
    }

  }
}