job "postgres" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 1
  group "postgres" {
    restart {
      attempts = 4
      interval = "30m"
      delay    = "20s"
      mode     = "fail"
    }
    volume "postgres" {
      type            = "csi"
      read_only       = false
      source          = "postgres-swfs"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }
    network {
      mode = "bridge"
      port "postgres" {
        static       = 5432
        host_network = "vpn"
      }
      port "metrics" {
        to           = 9187
        host_network = "vpn"
      }
    }
    task "postgres" {
      driver = "docker"
      config {
        image = "postgres:15.2"
        ports = ["postgres"]
      }
      env = {
        "POSTGRES_USER"     = "postgres"
        "POSTGRES_PASSWORD" = "yolo"
        "POSTGRES_DB"       = "postgres"
        "PGDATA" = "/var/lib/postgresql/data_mount"
      }
      volume_mount {
        volume      = "postgres"
        destination = "/var/lib/postgresql/data_mount"
        read_only   = false
      }
      resources {
        cpu    = 120
        memory = 250
      }
      service {
        name     = "postgres"
        port     = "postgres"
        provider = "nomad"
        # checks are not working for some reason
        #                check {
        #                    name     = "alive"
        #                    type     = "tcp"
        #                    interval = "20s"
        #                    timeout  = "2s"
        #                }
        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}.rule=HostSNI(`vps.dcotta.eu`)",
          #                    "traefik.tcp.routers.${NOMAD_TASK_NAME}.entrypoints=postgres,postgres-public",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}.entrypoints=postgres,postgres_public",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",

          "traefik.tcp.routers.${NOMAD_TASK_NAME}-web.rule=HostSNI(`db.web.dcotta.eu`)",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}-web.entrypoints=web,websecure",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}-web.tls=true",
          "traefik.tcp.routers.${NOMAD_TASK_NAME}-web.tls.certresolver=lets-encrypt",
        ]
      }
    }

    # metrics
    task "metrics" {
      lifecycle {
        sidecar = true
        hook    = "poststart"
      }
      driver = "docker"
      config {
        image = "prometheuscommunity/postgres-exporter:latest"
        ports = ["metrics"]
      }
      env = {
        # TODO [1] use vault
        "DATA_SOURCE_NAME" = "postgresql://postgres_exporter:password@localhost:${NOMAD_PORT_postgres}/marti_phd?sslmode=disable"
      }
      service {
        name     = "postgres-metrics"
        port     = "metrics"
        provider = "nomad"
        tags     = ["metrics"]
      }
      resources {
        cpu    = 90
        memory = 100
      }
    }
  }
}