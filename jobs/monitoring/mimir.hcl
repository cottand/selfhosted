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
    ephemeral_disk {
      size    = 1024 # MB
      migrate = true
      sticky  = true
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
      # so that blocks can be flushed
      kill_timeout = "5m"
      config {
        image = "grafana/mimir:2.9.0"
        args = [
          "-config.file",
          "/local/config.yaml",
          "-target=all",
          "-auth.multitenancy-enabled=false",
          "-query-frontend.parallelize-shardable-queries=true",
        ]
        ports = ["http", "memberlist"]
      }
      template {
        change_mode = "restart"
        data        = <<EOH
        # https://github.com/grafana/mimir/blob/main/development/mimir-monolithic-mode/config/mimir.yaml

        
server:
  http_listen_port: {{ env "NOMAD_PORT_http" }}
common:
  storage:
    backend: s3
    s3:
      {{ range nomadService "seaweedfs-filer-s3" }}
      endpoint: {{ .Address}}:{{ .Port }}
      {{ end }}
      insecure: true
      region: us-east
      bucket_name: mimir
  
blocks_storage:
  storage_prefix: blocks
  tsdb:
    flush_blocks_on_shutdown: true
    dir: /data/ingester
    # (advanced) If TSDB has not received any data for this duration, and all
    # blocks from TSDB have been shipped, TSDB is closed and deleted from local
    # disk. If set to positive value, this value should be equal or higher than
    # -querier.query-ingesters-within flag to make sure that TSDB is not closed
    # prematurely, which could cause partial query results. 0 or negative value
    # disables closing of idle TSDB.
    # close_idle_tsdb_timeout: 3h #| default = 13h

    # TSDB blocks retention in the ingester before a block is removed. If shipping
    # is enabled, the retention will be relative to the time when the block was
    # uploaded to storage. If shipping is disabled then its relative to the
    # creation time of the block. This should be larger than the
    # -blocks-storage.tsdb.block-ranges-period, -querier.query-store-after and
    # large enough to give store-gateways and queriers enough time to discover
    # newly uploaded blocks.
    retention_period: 3h # default = 13h
    block_ranges_period: [ 2h ]
    ship_interval: 1m
  bucket_store:
    # Directory to store synchronized TSDB index headers. This directory is not
    # required to be persisted between restarts, but it's highly recommended in
    # order to improve the store-gateway startup time.
    sync_dir: /data/tsdb-sync



ingester:
  ring:
    replication_factor: 1

store_gateway:
  sharding_ring:
    replication_factor: 1

limits:
  compactor_blocks_retention_period: 30d
  # (advanced) Maximum lookback beyond which queries are not sent to ingester
  # query_ingesters_within: 3h # default = 13h
  native_histograms_ingestion_enabled: true

querier:
  query_store_after: 2h

ruler_storage:
  s3:
    bucket_name: mimir-ruler
EOH
        destination = "local/config.yaml"
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