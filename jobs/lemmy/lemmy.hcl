variable "lemmy_version" {
  type    = string
  default = "0.18.5"
}

variable "image" {
  type    = string
  // default = "dessalines/lemmy"
  // this one is in GHCR and supports ARM:
  default = "ghcr.io/ubergeek77/lemmy"
}

job "lemmy" {
  update {
    max_parallel = 1
    stagger      = "10s"
  }
  datacenters = ["dc1"]
  type        = "service"
  group "frontend" {
    count = 2
    network {
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
        to           = 80
      }
    }

    task "lemmy-ui" {
      driver = "docker"

      config {
        image = "${var.image}-ui:${var.lemmy_version}"
        ports = ["http"]
      }
      env {
        # this needs to match the hostname defined in the lemmy service
        # set the outside hostname here
        LEMMY_UI_LEMMY_EXTERNAL_HOST = "r.dcotta.eu"
        LEMMY_UI_HOST                = "0.0.0.0:${NOMAD_PORT_http}"
        LEMMY_HTTPS                  = false
        LEMMY_UI_DEBUG               = true
      }

      service {
        name     = "lemmy-ui"
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
          # for some reason only when there is a longer hostname this works
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`r.dcotta.eu`) || Host(`lemmy.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure_public,websecure,web_public,web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
        ]
      }
      template {
        destination = "config/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
          {{ range nomadService "lemmy-be" }}
          LEMMY_UI_LEMMY_INTERNAL_HOST={{ .Address }}:{{ .Port }}
          {{ end }}
          EOH
      }
      resources {
        cpu    = 90
        memory = 90
      }
    }
  }

  group "backend" {

    update {
      min_healthy_time  = "10s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
    }
    restart {
      interval = "10m"
      attempts = 8
      delay    = "15s"
      mode     = "delay"
    }
    network {
      mode = "bridge"
      port "lemmy" { host_network = "wg-mesh" }
      port "metrics" { host_network = "wg-mesh" }
      port "db" { host_network = "wg-mesh" }
    }

    task "lemmy-be" {
      driver = "docker"

      config {
        image = "${var.image}:${var.lemmy_version}"
        volumes = [
          "local/lemmy.hjson:/etc/lemmy/lemmy.hjson",
        ]
      }
      env {
        LEMMY_CONFIG_LOCATION = "/etc/lemmy/lemmy.hjson"
        RUST_LOG              = "warn"
      }

      service {
        name     = "lemmy-be"
        port     = "lemmy"
        provider = "nomad"
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 4
            grace           = "20s"
            ignore_warnings = false
          }
        }
        tags = [
          "traefik.enable=true",
          # for some reason only when there is a longer hostname this works
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=(Host(`lemmy.dcotta.eu`) || Host(`r.dcotta.eu`)) && (PathPrefix(`/api`) || PathPrefix(`/pictrs`) || PathPrefix(`/feeds`) || PathPrefix(`/nodeinfo`) || PathPrefix(`/.well-known`) || Method(`POST`) || HeaderRegexp(`Accept`, `^[Aa]pplication/.*`))",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure_public,websecure,web_public,web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
        ]
      }
      service {
        name     = "lemmy-metrics"
        port     = "metrics"
        provider = "nomad"
        tags     = ["metrics"]
      }
      template {

        change_mode = "restart"
        destination = "local/lemmy.hjson"
        data        = <<EOH
{
  database: {
    {{ with nomadVar "nomad/jobs/lemmy" }}
    password: "{{ .db_password }}"
    {{ end }}
    {{ range nomadService "lemmy-db" }}
    host: "{{ .Address }}"
    port: {{ .Port }}
    {{ end }}
    user: "lemmy"
    database: "lemmy"
    pool_size: 5
  }
  # replace with your domain
  hostname: r.dcotta.eu
  bind: "0.0.0.0"
  port: {{ env "NOMAD_PORT_lemmy" }}
  federation: {
    enabled: false
  }
  # remove this block if you don't require image hosting
  {{- range nomadService "lemmy-pictrs" }}
  pictrs: {
    url: "http://{{ .Address }}:{{ .Port }}/"
  }
  {{- end }}
  # Whether the site is available over TLS. Needs to be true for federation to work.
  #tls_enabled: true
  prometheus: {
    bind: "0.0.0.0"
    port: {{ env "NOMAD_PORT_metrics" }}
  }
  setup: {
    # Username for the admin user
    admin_username: "admin"
    # Password for the admin user. It must be at least 10 characters.
    admin_password: "admin"
    # Name of the site (can be changed later)
    site_name: "D'Cotta Lemmy"
    # Email for the admin user (optional, can be omitted and set later through the website)
    # admin_email: "nico@dcotta.eu"
  }
}
EOH
      }
      resources {
        cpu = 200
        # docs say it should use about 150 MB
        memory = 150
      }
    }

  }
  group "postgres" {
    restart {
      attempts = 4
      interval = "10m"
      delay    = "20s"
      mode     = "delay"
    }
    volume "postgres" {
      type      = "host"
      read_only = false
      source    = "lemmy-data"
    }
    network {
      mode = "bridge"
      port "postgres" {
        to           = 5432
        host_network = "wg-mesh"
      }
      port "metrics" {
        to           = 9187
        host_network = "wg-mesh"
      }
    }
    task "postgres" {
      driver = "docker"
      config {
        image = "postgres:15.2"
        ports = ["postgres"]
      }
      env = {
        "POSTGRES_USER" = "lemmy"
        "POSTGRES_DB"   = "lemmy"
        // "PGDATA"            = "/var/lib/postgresql/data_mount"
      }
      template {
        destination = "config/.env"
        env         = true
        change_mode = "restart"
        data        = <<EOH
{{- with nomadVar "nomad/jobs/lemmy" -}}
POSTGRES_PASSWORD={{ .db_password }}
{{- end -}}
EOH

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
        name     = "lemmy-db"
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