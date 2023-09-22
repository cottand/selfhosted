job "tempo" {
  datacenters = ["dc1"]
  type        = "service"
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
  }
  group "tempo" {
    ephemeral_disk {
      migrate = true
      size    = 5000
      sticky  = true
    }
    count = 1
    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    network {
      mode = "bridge"
      dns {
        servers = [
          "10.10.0.1",
          "10.10.2.1",
          "10.10.4.1",
          "10.10.1.1",
        ]
      }
      port "http" {
        host_network = "wg-mesh"
      }
      port "grpc" {
        host_network = "wg-mesh"
      }
      port "otlp-grpc" {
        host_network = "wg-mesh"
      }
      # see https://www.jaegertracing.io/docs/1.47/deployment/#collector
      port "jaeger-thrift-compact" {
        to           = 6831
        host_network = "wg-mesh"

      }
      port "jaeger-ingest" {
        // to = 14268
        host_network = "wg-mesh"
      }
    }
    task "tempo" {
      driver = "docker"
      user   = "root" // !! so it can access the container volume, must be user
      // of folder in host

      config {
        image = "grafana/tempo:2.2.3"
        args = [
          "-config.file",
          "local/tempo/local-config.yaml",
        ]
        ports = [
          "http",
          "grpc-otlp",
          "jaeger-ingest",
          "jaeger-http-sampling",
          "jaeger-thrift-compact",
        ]
      }
      template {
        destination = "local/tempo/local-config.yaml"
        data        = <<EOH
auth_enabled: false
server:
  http_listen_port: {{ env "NOMAD_PORT_http" }}
  grpc_listen_port: {{ env "NOMAD_PORT_grpc" }}

distributor:
  # each of these has their separate config - see https://grafana.com/docs/tempo/latest/configuration/#distributor
  receivers:
    # see https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/jaegerreceiver
    jaeger:
      protocols:
        thrift_http:                   
          endpoint: 0.0.0.0:{{ env "NOMAD_PORT_jaeger_ingest" }}
        thrift_compact: # UDP
          endpoint: 0.0.0.0:{{ env "NOMAD_PORT_jaeger_thrift_compact" }}
    otlp:
      protocols:
          grpc:
            endpoint: 0.0.0.0:{{ env "NOMAD_PORT_otlp_grpc" }}
          #http:

ingester:
  max_block_duration: 5m               # cut the headblock when this much time passes. this is being set for demo purposes and should probably be left alone normally

compactor:
  compaction:
    block_retention: 1h                # overall Tempo trace retention.

metrics_generator:
  registry:
    external_labels:
      source: tempo
      cluster: nomad
  storage:
    path: /alloc/data/tempo/generator/wal
    remote_write:
      - url: http://mimir.traefik/api/v1/push
        send_exemplars: true
  
storage:
  trace:
    backend: local                     # backend configuration to use
    wal:
      path: /alloc/data/tempo/wal             # where to store the the wal locally
    local:
      path: /alloc/data/tempo/blocks

overrides:
  metrics_generator_processors: [service-graphs, span-metrics] # enables metrics generator
EOH
      }
      resources {
        cpu        = 256
        memory     = 256
        memory_max = 1024
      }
      service {
        name     = "tempo"
        port     = "http"
        provider = "nomad"
        check {
          name     = "tempo healthcheck"
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
        name     = "tempo-jaeger-thrift-compact"
        port     = "jaeger-thrift-compact"
        provider = "nomad"
      }
      service {
        name     = "tempo-jaeger-ingest"
        port     = "jaeger-ingest"
        provider = "nomad"
      }
      service {
        name     = "tempo-otlp-grpc"
        port     = "otlp-grpc"
        provider = "nomad"
      }
    }
  }
}