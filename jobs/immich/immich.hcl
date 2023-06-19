job "immich" {
  datacenters = ["<your-datacenter>"]

  group "immich-server" {
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
        image = "ghcr.io/immich-app/immich-server:release"
        command = ["start-server.sh"]
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
        name = "immich-server"
        port = 8080
      }

      depends_on = ["redis", "database", "typesense"]
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
