variable "ports" {
  type = map(number)
  default = {
    http       = 5001
    grpc       = 5002
    memberlist = 7946
  }
}

job "mimir" {
  datacenters = ["*"]
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
    affinity {
      attribute = "${meta.controlPlane}"
      value     = "true"
      weight    = -50
    }
    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    ephemeral_disk {
      size = 1024 # MB
      migrate = true
      sticky  = true
    }
    network {
      mode = "bridge"
      port "healthz" {
        to           = -1
        host_network = "ts"
      }
      port "metrics" {
        to           = -1
        host_network = "ts"
      }
      port "memberlist" {
        host_network = "ts"
        to           = 7946
      }
      port "grpc" {
        host_network = "ts"
      }
    }
    service {
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "tempo-otlp-grpc-mesh"
              local_bind_port  = 9001
            }
          }
        }
      }
      name = "mimir-http"
      port = "${var.ports.http}"
      check {
        name     = "healthz"
        port     = "healthz"
        type     = "http"
        path     = "/ready"
        interval = "20s"
        timeout  = "5s"
        check_restart {
          limit           = 6
          grace           = "120s"
          ignore_warnings = false
        }
        expose = true
      }
      check {
        name     = "metrics"
        port     = "metrics"
        type     = "http"
        path     = "/metrics"
        interval = "20s"
        timeout  = "5s"
        expose   = true
        check_restart {
          limit           = 6
          grace           = "120s"
          ignore_warnings = false
        }
      }
      meta {
        metrics_port = "${NOMAD_HOST_PORT_metrics}"
      }
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web, websecure",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls=true",
      ]
    }
    service {
      name = "mimir-memberlist"
      port = "${var.ports.memberlist}"
    }
    task "mimir" {
      driver = "docker"
      # so that blocks can be flushed
      kill_timeout = "5m"
      config {
        image = "grafana/mimir:2.12.0"
        args  = [
          "-config.file",
          "/local/config.yaml",
          "-target=all,alertmanager",
          "-auth.multitenancy-enabled=false",
          // "-query-frontend.parallelize-shardable-queries=true",
          // "-query-frontend.query-sharding-total-shards=4",
          // "-query-frontend.query-sharding-max-sharded-queries=12",
          // "-query-frontend.split-queries-by-interval=6h",
          "-server.grpc.keepalive.min-time-between-pings=10s",
        ]
        ports = ["http", "memberlist"]
      }
      template {
        change_mode = "restart"
        data        = <<EOH
        # https://github.com/grafana/mimir/blob/main/development/mimir-monolithic-mode/config/mimir.yaml
        # see https://github.com/grafana/mimir/discussions/3501#discussioncomment-4282204
              
server:
  http_listen_port: ${var.ports.http}
  grpc_listen_port: ${var.ports.grpc}
common:
  storage:
    backend: s3
    s3:
      send_content_md5: true
      bucket_name: mimir-long-term
      endpoint: s3.us-east-005.backblazeb2.com
      region: us-east-005
      {{ with nomadVar "secret/buckets/backblaze-all" }}
      secret_access_key: {{ .secretAccessKey }}
      access_key_id: {{ .keyId }}
      {{ end }}

blocks_storage:
  storage_prefix: blocks
  tsdb:
    flush_blocks_on_shutdown: true
    dir: /alloc/data/ingester
    # (advanced) If TSDB has not received any data for this duration, and all
    # blocks from TSDB have been shipped, TSDB is closed and deleted from local
    # disk. If set to positive value, this value should be equal or higher than
    # -querier.query-ingesters-within flag to make sure that TSDB is not closed
    # prematurely, which could cause partial query results. 0 or negative value
    # disables closing of idle TSDB.
    # close_idle_tsdb_timeout: 4h #| default = 13h

    # TSDB blocks retention in the ingester before a block is removed. If shipping
    # is enabled, the retention will be relative to the time when the block was
    # uploaded to storage. If shipping is disabled then its relative to the
    # creation time of the block. This should be larger than the
    # -blocks-storage.tsdb.block-ranges-period, -querier.query-store-after and
    # large enough to give store-gateways and queriers enough time to discover
    # newly uploaded blocks.
    # retention_period: 5h # default = 13h
    # block_ranges_period: [ 2h ] # block size basically?
    # ship_interval: 1m
  bucket_store:
    # Directory to store synchronized TSDB index headers. This directory is not
    # required to be persisted between restarts, but it's highly recommended in
    # order to improve the store-gateway startup time.
    sync_dir: /alloc/data/tsdb-sync



ingester:
  ring:
    replication_factor: 1

store_gateway:
  sharding_ring:
    replication_factor: 1

limits:
  compactor_blocks_retention_period: 30d
  # (advanced) Maximum lookback beyond which queries are not sent to ingester
  # query_ingesters_within: 5h # default = 13h
  native_histograms_ingestion_enabled: true

querier:
  # query_store_after: 4h
  max_concurrent: 10 # default 20

# ruler_storage:
#   s3:
#     bucket_name: mimir-ruler
EOH
        destination = "local/config.yaml"
      }
      resources {
        cpu        = 256
        memory     = 1024
        memory_max = 1024
      }
    }
  }
}