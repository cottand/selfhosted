job "immich_job" {
  type        = "service"

  group "immich_group" {
    count = 1

    network {
      port "immich_web_port" {
        static       = "2282"
        to           = "3000"
        host_network = "tailscale"
      }

      port "immich_server_port" {
        static       = "2283"
        to           = "3001"
        host_network = "tailscale"
      }

      # purposefully skipping exposing microservices as per
      # https://github.com/immich-app/immich/pull/930/files#diff-ec10582dde9af6c0c622084d3244b29d496260613491c430ec8958565e2f31b4R76

      port "immich_machine_learning_port" {
        static       = "2285"
        to           = "3003"
        host_network = "tailscale"
      }

      port "immich_typesense_port" {
        static       = "2286"
        to           = "8108"
        host_network = "tailscale"
      }
    }

    volume "immich_originals_volume" {
      type      = "host"
      source    = "photoprism_originals_hdd_volume"
      read_only = false
    }

    volume "typesense_volume" {
      type      = "host"
      source    = "immich_typesense_hdd_volume"
      read_only = false
    }

    restart {
      attempts = 3
      interval = "25m"
      delay    = "1m"
      mode     = "delay"
    }

    task "main_immich_server" {
      driver = "docker"

      resources {
        memory_max = 1024
      }

      env = {
        NODE_ENV = "production"
        DB_HOSTNAME = "{{ Hostname }}"
        DB_USERNAME = "{{ ImmichUsername }}"
        DB_PASSWORD = "{{ ImmichPassword }}"
        DB_DATABASE_NAME = "{{ ImmichDatabase }}"
        REDIS_HOSTNAME = "{{ RedisHostname }}"
        JWT_SECRET = "{{ ImmichJwtSecret }}"
        ENABLE_MAPBOX = "false"
        IMMICH_WEB_URL = "{{ Hostname }}:2282"
        IMMICH_SERVER_URL = "{{ Hostname }}:2283"
        IMMICH_MACHINE_LEARNING_URL = "{{ Hostname }}:2285"
        TYPESENSE_API_KEY = "{{ TypesenseAPIKey }}"
        TYPESENSE_HOST = "{{ Hostname }}"
        TYPESENSE_PORT = "2286"
      }

      volume_mount {
        volume      = "immich_originals_volume"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      config {
        image = "ghcr.io/immich-app/immich-server:release"
        command    = "start-server.sh"
        ports = ["immich_server_port"]
      }
    }

    task "immich_microservices" {
      driver = "docker"

      resources {
        memory_max = 1024
      }

      env = {
        NODE_ENV = "production"
        DB_HOSTNAME = "{{ Hostname }}"
        DB_USERNAME = "{{ ImmichUsername }}"
        DB_PASSWORD = "{{ ImmichPassword }}"
        DB_DATABASE_NAME = "{{ ImmichDatabase }}"
        REDIS_HOSTNAME = "{{ RedisHostname }}"
        JWT_SECRET = "{{ ImmichJwtSecret }}"
        ENABLE_MAPBOX = "false"
        IMMICH_WEB_URL = "{{ Hostname }}:2282"
        IMMICH_SERVER_URL = "{{ Hostname }}:2283"
        IMMICH_MACHINE_LEARNING_URL = "{{ Hostname }}:2285"
        TYPESENSE_API_KEY = "{{ TypesenseAPIKey }}"
        TYPESENSE_HOST = "{{ Hostname }}"
        TYPESENSE_PORT = "2286"
      }

      volume_mount {
        volume      = "immich_originals_volume"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      config {
        image = "ghcr.io/immich-app/immich-server:release"
        command    = "start-microservices.sh"
      }
    }

    task "immich_machine_learning" {
      driver = "docker"

      resources {
        memory_max = 512
      }

      env = {
        NODE_ENV = "production"
        DB_HOSTNAME = "{{ Hostname }}"
        DB_USERNAME = "{{ ImmichUsername }}"
        DB_PASSWORD = "{{ ImmichPassword }}"
        DB_DATABASE_NAME = "{{ ImmichDatabase }}"
        REDIS_HOSTNAME = "{{ RedisHostname }}"
        JWT_SECRET = "{{ ImmichJwtSecret }}"
        ENABLE_MAPBOX = "false"
        IMMICH_WEB_URL = "{{ Hostname }}:2282"
        IMMICH_SERVER_URL = "{{ Hostname }}:2283"
        IMMICH_MACHINE_LEARNING_URL = "{{ Hostname }}:2285"
      }

      volume_mount {
        volume      = "immich_originals_volume"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      config {
        image = "altran1502/immich-machine-learning:release"
      }
    }

    task "immich_typesense" {
      driver = "docker"

      resources {
        memory_max = 512
      }

      env = {
        TYPESENSE_API_KEY = "{{ TypesenseAPIKey }}"
        TYPESENSE_DATA_DIR = "/data"
      }

      volume_mount {
        volume      = "typesense_volume"
        destination = "/data"
        read_only   = false
      }

      config {
        image = "typesense/typesense:0.24.0"
        ports = ["immich_typesense_port"]
      }
    }

    task "immich_web" {
      driver = "docker"

      env = {
        IMMICH_SERVER_URL = "http://{{ Hostname }}:2283"
      }

      config {
        image = "ghcr.io/immich-app/immich-web:release"
        ports = ["immich_web_port"]
      }
    }

  }
}