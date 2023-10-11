
variable "version" {
  type    = string
  default = "v1.81.1"
}

job "immich" {
  // datacenters = ["<your-datacenter>"]

  group "immich" {

    network {
      mode = "bridge"
      port "http" {
        static       = 80
        host_network = "vpn"
      }
    }
    volume "immich_photos" {
      type            = "csi"
      read_only       = false
      source          = "immich_photos"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    task "immich-server" {
      driver = "docker"

      config {
        image = "ghcr.io/immich-app/immich-server:${var.version}"
        command = [ "start.sh", "immich" ]
        env {
          # https://immich.app/docs/install/environment-variables
          ENV_FILE = "/path/to/.env"
          IMMICH_CONFIG_FILE = "/etc/immich/config"
          REVERSE_GEOCODING_DUMP_DIRECTORY = TODO
          SERVER_PORT = ${env.}
        }
        volumes = [
          "local/config:/etc/immich/config",
        ] 
      }
      volume_mount {
        volume      = "immich_photos"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      resources { # TODO!
        cpu    = 100
        memory = 256
      }

      service {
        name = "immich-server"
        port = 8080
      }
      template {
        data        = <<EOF
EOF
        destination = "local/config"
        change_mode = "signal"
      }
    }
  }

  group "immich-microservices" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    task "immich-microservices" {
      driver = "docker"

      config {
        image = "ghcr.io/immich-app/immich-server:release"
        command = ["start-microservices.sh"]
        volumes = [
          "${UPLOAD_LOCATION}:/usr/src/app/upload"
        ]
        env {
          ENV_FILE = "/path/to/.env"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "immich-microservices"
        port = 8081
      }

      depends_on = ["redis", "database", "typesense"]
    }
  }

  group "immich-machine-learning" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    task "immich-machine-learning" {
      driver = "docker"

      config {
        image = "ghcr.io/immich-app/immich-machine-learning:release"
        volumes = [
          "${UPLOAD_LOCATION}:/usr/src/app/upload",
          "model-cache:/cache"
        ]
        env {
          ENV_FILE = "/path/to/.env"
        }
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "immich-machine-learning"
        port = 8082
      }
    }
  }

  group "immich-web" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }

    task "immich-web" {
      driver = "docker"

      config {
        image = "ghcr.io/immich-app/immich-web:release"
        env {
          ENV_FILE = "/path/to/.env"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "immich-web"
        port = 8083
      }
    }
  }
}
