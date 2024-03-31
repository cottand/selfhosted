variable ports {
  type = map(string)
  default = {
    http = 12346
    grpc = 12347
    otlp_grpc = 12348
    jaeger_thrift_compact = 6831
    jaeger_ingest = 6891
  }
}

job "tempo" {
  datacenters = ["*"]
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
      port "metrics" {
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
      service {
        name     = "tempo-metrics"
        port     = "${var.ports.http}"
        check {
          expose = true
          name     = "tempo healthcheck"
          port     = "metrics"
          type     = "http"
          path     = "/metrics"
          interval = "20s"
          timeout  = "5s"
          check_restart {
            limit           = 3
            grace           = "120s"
            ignore_warnings = false
          }
        }
        meta {
          metrics_port = "${NOMAD_PORT_http}"
        }
        connect {
        sidecar_service {
          proxy {}
        }
        }
      }
      service {
        name     = "tempo-http"
        port     = "${var.ports.http}"
        tags = [
        "traefik.consulcatalog.connect=true",
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web,websecure",
          "traefik.http.routers.${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls.certresolver=dcotta-vault"
        ]
        connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mimir-http"
              local_bind_port  = 8001
            }
          }
        }
        }
      }
      service {
        name     = "tempo-jaeger-thrift-compact"
        port     = "jaeger-thrift-compact"
        // provider = "nomad"
      }
      service {
        name     = "tempo-jaeger-ingest"
        port     = "jaeger-ingest"
        // provider = "nomad"
      }
      service {
        name     = "tempo-otlp-grpc"
        port     = "otlp-grpc"
        // provider = "nomad"
      }
    task "tempo" {
      driver = "docker"
      user   = "root" // !! so it can access the container volume, must be user
      // of folder in host

      config {
        image = "grafana/tempo:2.3.1"
        args = [
          "-config.file",
          "local/tempo/local-config.yaml",
        ]
      }
      template {
        destination = "local/tempo/local-config.yaml"
        data        = <<EOH
auth_enabled: false
server:
  http_listen_port: ${var.ports.http}
  grpc_listen_port: ${var.ports.grpc}

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
      - url: http://localhost:8001/api/v1/push
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
        cpu        = 350
        memory     = 256
        memory_max = 1024
      }
    }
  }
}
