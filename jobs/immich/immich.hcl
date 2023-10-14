
variable "version" {
  type    = string
  default = "v1.81.1"
}
variable "domain" {
  type    = string
  default = "immich.traefik"
}

job "immich" {
  group "immich-frontend" {
    network {
      dns {
        servers = ["10.10.0.1", "10.10.2.1", "10.10.4.1"]
      }
      mode = "bridge"
      port "http" { host_network = "wg-mesh" }
    }
    task "immich-web" {
      driver = "docker"
      config {
        image = "ghcr.io/immich-app/immich-web:${var.version}"
      }
      env {
        PORT = "${NOMAD_PORT_http}"
        # forwards via traefik so no need for service discovery
        // PUBLIC_IMMICH_SERVER_URL = "http://immich.traefik"
        // IMMICH_SERVER_URL = "http://immich.traefik"
        NODE_ENV = "production"
        // IMMICH_API_URL_EXTERNAL	= "/api"
      }

      resources {
        cpu    = 200
        memory = 128
      }
      service {
        name     = "immich" # grimd inferred from here for immich.traefik
        provider = "nomad"
        port     = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${var.domain}`)",
        ]
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
      }
      template {
        destination = "config/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
        {{ range nomadService "immich-server" }}
        PUBLIC_IMMICH_SERVER_URL=http://{{ .Address }}:{{ .Port }}
        IMMICH_SERVER_URL=http://{{ .Address }}:{{ .Port }}
        {{ end }}
        EOH
      }
      #"http://immich-server.traefik"
    }
  }

  group "immich_backend" {
    count = 1

    network {
      mode = "bridge"
      dns {
        servers = ["10.10.0.1", "10.10.2.1", "10.10.4.1"]
      }
      port "server" {
        host_network = "wg-mesh"
        to           = 3001
      }
      port "microservices" {
        host_network = "wg-mesh"
        to           = 3002
      }
    }
    volume "immich_pictures" {
      type            = "csi"
      read_only       = false
      source          = "immich-pictures"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "10s"
      mode     = "delay"
    }
    task "init-config" {
      lifecycle { hook = "prestart" }
      template {
        destination     = "${NOMAD_ALLOC_DIR}/config.json"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data            = <<EOH
        {
          "ffmpeg": {
            "crf": 23,
            "threads": 0,
            "preset": "ultrafast",
            "targetVideoCodec": "h264",
            "targetAudioCodec": "aac",
            "targetResolution": "720",
            "maxBitrate": "0",
            "twoPass": false,
            "transcode": "required",
            "tonemap": "hable",
            "accel": "disabled"
          },
          "job": {
            "backgroundTask": {
              "concurrency": 5
            },
            "clipEncoding": {
              "concurrency": 2
            },
            "metadataExtraction": {
              "concurrency": 5
            },
            "objectTagging": {
              "concurrency": 2
            },
            "recognizeFaces": {
              "concurrency": 2
            },
            "search": {
              "concurrency": 5
            },
            "sidecar": {
              "concurrency": 5
            },
            "storageTemplateMigration": {
              "concurrency": 5
            },
            "thumbnailGeneration": {
              "concurrency": 5
            },
            "videoConversion": {
              "concurrency": 1
            }
          },
          "machineLearning": {
            "classification": {
              "minScore": 0.7,
              "enabled": true,
              "modelName": "microsoft/resnet-50"
            },
            "enabled": true,
            "url": "http://immich-ml.traefik",
            "clip": {
              "enabled": true,
              "modelName": "ViT-B-32::openai"
            },
            "facialRecognition": {
              "enabled": true,
              "modelName": "buffalo_l",
              "minScore": 0.7,
              "maxDistance": 0.6,
              "minFaces": 1
            }
          },
          "oauth": {
            "enabled": false,
            "issuerUrl": "",
            "clientId": "",
            "clientSecret": "",
            "mobileOverrideEnabled": false,
            "mobileRedirectUri": "",
            "scope": "openid email profile",
            "storageLabelClaim": "preferred_username",
            "buttonText": "Login with OAuth",
            "autoRegister": true,
            "autoLaunch": false
          },
          "passwordLogin": {
            "enabled": true
          },
          "storageTemplate": {
            "template": "{{y}}-{{MM}}/{{filename}}"
          },
          "thumbnail": {
            "webpSize": 250,
            "jpegSize": 1440,
            "quality": 90,
            "colorspace": "p3"
          }
        }
      EOH
      }

      driver = "docker"
      config { image = "hello-world" }
      resources { # TODO!
        cpu    = 10
        memory = 10
      }
    }
    task "immich-server" {
      driver = "docker"

      config {
        image   = "ghcr.io/immich-app/immich-server:${var.version}"
        command = "start.sh"
        args    = ["immich"]
      }
      env {
        # https://immich.app/docs/install/environment-variables
        IMMICH_CONFIG_FILE = "${NOMAD_ALLOC_DIR}/config.json"
        TYPESENSE_ENABLED  = true
        // REVERSE_GEOCODING_DUMP_DIRECTORY = TODO
      }
      volume_mount {
        volume      = "immich_pictures"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      resources { # TODO!
        cpu    = 100
        memory = 256
      }

      service {
        name     = "immich-server"
        provider = "nomad"
        port     = "server"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${var.domain}`) && Pathprefix(`/api`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=${NOMAD_TASK_NAME}-strip",
          "traefik.http.middlewares.${NOMAD_TASK_NAME}-strip.stripprefix.prefixes=/api",
        ]
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
      }
      template {
        destination = "config/.env"
        env         = true
        data        = <<EOH
        {{ with nomadVar "nomad/jobs/immich" }}
        TYPESENSE_API_KEY="{{ .typesense_api_key }}"
        DB_PASSWORD="{{ .db_password }}"
        DB_USERNAME={{ .db_user }}
        DB_DATABASE_NAME="immich"
        {{ end -}}
        {{ range nomadService "immich-db" }}
        DB_HOSTNAME={{ .Address }}
        DB_PORT={{ .Port }}
        {{ end }}
        {{ range nomadService "immich-redis" }}
        REDIS_HOSTNAME={{ .Address }}
        REDIS_PORT={{ .Port }}
        {{ end }}


        IMMICH_SERVER_URL=http://{{ env "NOMAD_IP_server" }}:{{ env "NOMAD_HOST_PORT_server" }}

        {{ range nomadService "immich-typesense" -}}
        ENABLE_TYPESENSE="true"
        TYPESENSE_HOST={{ .Address }}
        TYPESENSE_PORT={{ .Port }}
        {{- end }}
        EOH
      }
    }
    task "immich-microservices" {
      driver = "docker"

      config {
        image   = "ghcr.io/immich-app/immich-server:${var.version}"
        command = "start.sh"
        args    = ["microservices"]
      }
      env {
        # https://immich.app/docs/install/environment-variables
        IMMICH_CONFIG_FILE = "${NOMAD_ALLOC_DIR}/config.json"
        // REVERSE_GEOCODING_DUMP_DIRECTORY = TODO
        MICROSERVICES_PORT = "${NOMAD_PORT_microservices}"
        TYPESENSE_ENABLED  = true
      }
      volume_mount {
        volume      = "immich_pictures"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      resources { # TODO!
        cpu        = 512
        memory     = 1024
        memory_max = 1500
      }

      service {
        name     = "immich-microservices"
        provider = "nomad"
        port     = "microservices"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 3
            grace           = "40s"
            ignore_warnings = false
          }
        }
      }
      template {
        destination = "config/.env"
        env         = true
        data        = <<EOH
        {{ with nomadVar "nomad/jobs/immich" }}
        TYPESENSE_API_KEY="{{ .typesense_api_key }}"
        DB_PASSWORD="{{ .db_password }}"
        DB_USERNAME={{ .db_user }}
        DB_DATABASE_NAME="immich"
        {{ end -}}
        {{ range nomadService "immich-db" }}
        DB_HOSTNAME={{ .Address }}
        DB_PORT={{ .Port }}
        {{ end }}
        {{ range nomadService "immich-redis" }}
        REDIS_HOSTNAME={{ .Address }}
        REDIS_PORT={{ .Port }}
        {{ end }}


        IMMICH_SERVER_URL=http://{{ env "NOMAD_IP_server" }}:{{ env "NOMAD_HOST_PORT_server" }}

        {{ range nomadService "immich-typesense" -}}
        ENABLE_TYPESENSE="true"
        TYPESENSE_HOST={{ .Address }}
        TYPESENSE_PORT={{ .Port }}
        {{- end }}
        EOH
      }
    }
  }

  group "immich-ml" {
    network {
      dns {
        servers = ["10.10.0.1", "10.10.2.1", "10.10.4.1"]
      }
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
        to           = 3003
      }
    }
    volume "immich-ml-cache" {
      type            = "csi"
      read_only       = false
      source          = "immich-ml-cache"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }
    restart {
      attempts = 4
      interval = "10m"
      delay    = "20s"
      mode     = "delay"
    }
    task "immich-ml" {
      driver = "docker"

      volume_mount {
        volume      = "immich-ml-cache"
        destination = "/cache"
        read_only   = false
      }
      resources {
        memory_max = 1024
        memory     = 512
        cpu        = 100
      }

      env {
        # see https://immich.app/docs/install/environment-variables#machine-learning
        MACHINE_LEARNING_REQUEST_THREADS = 3
      }

      config {
        image = "ghcr.io/immich-app/immich-machine-learning:${var.version}"
        ports = ["http"]
      }
      service {
        name     = "immich-ml"
        provider = "nomad"
        port     = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web",
        ]
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 3
            grace           = "40s"
            ignore_warnings = false
          }
        }
      }
    }
  }


  group "immich-typesense" {
    network {
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
      }
    }
    volume "immich-typesense" {
      type            = "csi"
      read_only       = false
      source          = "immich-typesense"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
    }
    restart {
      attempts = 4
      interval = "10m"
      delay    = "20s"
      mode     = "delay"
    }
    task "immich-typesense" {
      driver = "docker"

      resources {
        memory_max = 512
        memory     = 100
        cpu        = 100
      }

      env = {
        TYPESENSE_DATA_DIR = "/data"
        TYPESENSE_API_PORT = "${NOMAD_PORT_http}"
        GLOG_minloglevel   = 1
      }

      volume_mount {
        volume      = "immich-typesense"
        destination = "/data"
        read_only   = false
      }

      config {
        image = "typesense/typesense:0.24.1"
        ports = ["http"]
      }
      template {
        destination = "config/.env"
        env         = true
        change_mode = "restart"
        data        = "{{ with nomadVar \"nomad/jobs/immich\" }}TYPESENSE_API_KEY={{ .typesense_api_key }}{{ end }}"
      }
      service {
        name     = "immich-typesense"
        provider = "nomad"
        port     = "http"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 3
            grace           = "40s"
            ignore_warnings = false
          }
        }
      }
    }
  }



  group "immich-dbs" {
    restart {
      attempts = 4
      interval = "10m"
      delay    = "20s"
      mode     = "delay"
    }
    volume "postgres" {
      type      = "host"
      read_only = false
      source    = "immich-db"
    }
    network {
      mode = "bridge"
      port "redis" {
        host_network = "wg-mesh"
        to           = 6379
      }
      port "postgres" {
        host_network = "wg-mesh"
        to           = 5432
      }
    }
    task "redis" {
      driver = "docker"
      config {
        image = "redis:7.2"
        ports = ["redis"]
      }
      env {
        REDIS_PASSWORD = "immich"
        REDIS_USERNAME = "immich"
        REDIS_PORT     = "${NOMAD_PORT_redis}"
      }
      service {
        name     = "immich-redis"
        port     = "redis"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
        }
      }
    }
    task "postgres" {
      driver = "docker"
      config {
        image = "postgres:15.2"
        ports = ["postgres"]
      }
      env = {
        "POSTGRES_USER" = "immich"
        "POSTGRES_DB"   = "immich"
      }
      template {
        destination = "config/.env"
        env         = true
        change_mode = "restart"
        data        = "{{ with nomadVar \"nomad/jobs/immich\" }}POSTGRES_PASSWORD={{ .db_password }}{{ end }}"
      }
      volume_mount {
        volume      = "postgres"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }
      resources {
        cpu    = 256
        memory = 750
      }
      service {
        name     = "immich-db"
        port     = "postgres"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
        }
      }
    }
  }
}
