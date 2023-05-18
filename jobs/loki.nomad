job "loki" {
    datacenters = ["dc1"]
    type        = "service"
    update {
        max_parallel      = 1
        health_check      = "checks"
        min_healthy_time  = "10s"
        healthy_deadline  = "3m"
        progress_deadline = "5m"
    }
    group "loki" {
        count = 1
        restart {
            attempts = 3
            interval = "5m"
            delay    = "25s"
            mode     = "delay"
        }
        network {
#            mode = "bridge" # no hairpin I think
            port "http" {
                host_network = "vpn"
            }
        }
        volume "loki" {
            type      = "host"
            read_only = false
            source    = "loki"
        }
        task "loki" {
            driver = "docker"
            user   = "root" // !! so it can access the container volume, must be user
            // of folder in host

            config {
                image = "grafana/loki:2.8.0"
                args  = [
                    "-config.file",
                    "local/loki/local-config.yaml",
                ]
                ports = ["http"]
                # [2] fix containers on maco unreachable in network mode bridge
                network_mode = "host"
            }
            volume_mount {
                volume      = "loki"
                destination = "/loki"
                read_only   = false
            }
            template {
                data        = <<EOH
auth_enabled: false
server:
  http_listen_port: {{ env "NOMAD_PORT_http" }}
ingester:
  wal:
    dir: /loki/wal
  lifecycler:
    # not sure it is needed but was in original guide
    #address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  # Any chunk not receiving new logs in this time will be flushed
  chunk_idle_period: 1h
  # All chunks will be flushed when they hit this age, default is 1h
  max_chunk_age: 1h
  # Loki will attempt to build chunks up to 1.5MB, flushing if chunk_idle_period or max_chunk_age is reached first
  chunk_target_size: 1048576
  # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
  chunk_retain_period: 30s
  max_transfer_retries: 0     # Chunk transfers disabled
schema_config:
  configs:
    - from: 2023-04-20
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h         # Can be increased for faster performance over longer query periods, uses more disk space
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks
compactor:
  working_directory: /tmp/loki/boltdb-shipper-compactor
  shared_store: filesystem
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
chunk_store_config:
  max_look_back_period: 0s
table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
# https://community.grafana.com/t/loki-error-on-port-9095-error-contacting-scheduler/67263
EOH
                destination = "local/loki/local-config.yaml"
            }
            resources {
                cpu    = 256
                memory = 512
                memory_max = 1024
            }
            service {
                name     = "loki"
                port     = "http"
                provider = "nomad"
                check {
                    name     = "Loki healthcheck"
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
                    "traefik.http.middlewares.${NOMAD_TASK_NAME}-stripprefix.stripprefix.prefixes=/${NOMAD_TASK_NAME}",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`web.vps.dcotta.eu`) && PathPrefix(`/${NOMAD_TASK_NAME}`)",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
                    "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=${NOMAD_TASK_NAME}-stripprefix,vpn-whitelist@file",
                ]
            }
        }
    }
}