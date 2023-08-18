job "mimir" {
  datacenters = ["dc1"]
  type        = "service"
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
  }
  group "mimir" {
    count = 1
    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    network {
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
      }
      port "memberlist" {
        host_network = "wg-mesh"
        to = 7946
      }
    }
    task "mimir" {
      driver = "docker"
      // user   = "root" // !! so it can access the container volume, must be user
      // of folder in host

      config {
        image = "grafana/mimir:2.9.0"
        args = [
          "-config.file",
          "local/mimir/local-config.yaml",
          "-target=all",
          "-auth.multitenancy-enabled=false",
        ]
        ports = ["http", "memberlist"]
      }
      template {
        change_mode = "signal"
        data        = <<EOH
server:
  http_listen_port: {{ env "NOMAD_PORT_http" }}
common:
  storage:
    backend: s3
    s3:
      {{ range $i, $s := nomadService "seaweedfs-filer-s3" }}
      {{- if eq $i 0 -}}
      endpoint: {{ .Address}}:{{ .Port }}
      insecure: true
      {{- end -}}
      {{ end }}
      region: us-east
      bucket_name: mimir
  
blocks_storage:
  storage_prefix: blocks
  tsdb:
    dir: /data/ingester

ingester:
  ring:
    replication_factor: 1

store_gateway:
  sharding_ring:
    replication_factor: 1

limits:
  compactor_blocks_retention_period: 7d
EOH
        destination = "local/mimir/local-config.yaml"
      }
      resources {
        cpu        = 256
        memory     = 512
        memory_max = 1024
      }
      service {
        name     = "mimir"
        port     = "http"
        provider = "nomad"
        check {
          name     = "mimir healthcheck"
          port     = "http"
          type     = "http"
          path     = "/ready"
          interval = "20s"
          timeout  = "5s"
          check_restart {
            limit           = 3
            grace           = "120s"
            ignore_warnings = false
          }
        }
        tags = [
          "metrics",
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web,websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
      service {
        name     = "mimir-memberlist"
        port     = "memberlist"
        provider = "nomad"
      }
    }
  }
}