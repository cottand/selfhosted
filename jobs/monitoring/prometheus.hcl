job "prometheus" {
  group "monitoring" {
    count = 1

    constraint {
      attribute = "${attr.nomad.bridge.hairpin_mode}"
      value     = true
    }

    network {
      dns {
        servers = ["100.100.100.100"]
      }
      mode = "bridge"
      port "health" {
        to = -1
        host_network = "ts"
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }
    update {
      max_parallel     = 1
      canary           = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
      auto_revert      = true
      auto_promote     = true
    }

    ephemeral_disk {
      size = 256 # MB
      migrate = true
      sticky  = true
    }
    service {
      name = "prometheus"
      port = "9090"

      check {
        expose   = true
        name     = "healthy"
        port     = "health"
        type     = "http"
        path     = "/-/healthy"
        interval = "20s"
        timeout  = "5s"
        check_restart {
          limit           = 3
          grace           = "120s"
          ignore_warnings = false
        }
      }
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
      tags = [
        "metrics",
        "traefik.enable=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web,websecure",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls=true",
      ]
    }

    task "prometheus" {
      vault {
        role = "telemetry-ro"
        env  = true
      }

      template {
        change_mode = "restart"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     20s
  evaluation_interval: 20s


scrape_configs:
  - job_name: nomad_nodes
    metrics_path: /v1/metrics
    scheme: https
    tls_config:
      insecure_skip_verify: true
    params:
      format: ['prometheus']

    static_configs:
      - labels: {'cluster': 'default'}

    consul_sd_configs:
    - server: 'https://{{ env "NOMAD_IP_health" }}:8501' # well known consul https port
      tls_config:
        insecure_skip_verify: true

    relabel_configs:
    # Only scrape nomad services
    - source_labels: ['__meta_consul_service']
      action: keep
      regex: (nomad(.+)client)

    - source_labels: ['__meta_consul_service']
      regex: '(.*)'
      action: replace
      target_label: service_name

    - source_labels: ['__meta_consul_service_id']
      action: replace
      regex: '(.*)'
      target_label: service_id

    - source_labels: ['__meta_consul_address']
      action: replace
      regex: '(.*)'
      target_label: node_ip

    - source_labels: ['__meta_consul_node']
      action: replace
      regex: '(.*)'
      target_label: node_id


  - job_name: 'cockroachdb'
    static_configs:
      - labels: {'cluster': 'dcotta'}
    tls_config:
      insecure_skip_verify: true
    consul_sd_configs:
    - server: 'https://{{ env "NOMAD_IP_health" }}:8501' # well known consul https port
      tls_config:
        insecure_skip_verify: true

    relabel_configs:
    # Only scrape services that have a metrics_port meta field.
    - source_labels: [__meta_consul_service_metadata_metrics_port]
      action: keep
      regex: (.+)
    
    # Replace the port in the address with the one from the metrics_port meta field.
    - source_labels: [__address__, __meta_consul_service_metadata_metrics_port]
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $${1}:$${2}
      target_label: __address__

    # Don't scrape -sidecar-proxy services that Consul sets up, otherwise we'll have duplicates.
    - source_labels: [__meta_consul_service]
      action: drop
      regex: (.+)-sidecar-proxy

    # Scrape only cockroachdb
    - source_labels: [__meta_consul_service]
      action: keep
      regex: roach-(.+)

    - source_labels: ['__meta_consul_service']
      regex: '(.*)'
      action: replace
      target_label: service_name

    - source_labels: ['__meta_consul_service_id']
      action: replace
      regex: '(.*)'
      target_label: service_id

    - source_labels: ['__meta_consul_address']
      action: replace
      regex: '(.*)'
      target_label: node_ip

    - source_labels: ['__meta_consul_node']
      action: replace
      regex: '(.*)'
      target_label: node_id

    - source_labels: [__meta_consul_service_metadata_external_source]
      action: replace
      regex: '(.*)'
      target_label: service_source

    # set metrics path to /metrics by default but override with meta=metrics_path
    - target_label:  __metrics_path__
      replacement: "/_status/vars"
      action: replace


  - job_name: 'consul_services'
    tls_config:
      insecure_skip_verify: true

    # Labels assigned to all metrics scraped from the targets.
    static_configs:
      - labels: {'cluster': 'dcotta'}
     
    consul_sd_configs:
    - server: 'https://{{ env "NOMAD_IP_health" }}:8501' # well known consul https port
      tls_config:
        insecure_skip_verify: true

    relabel_configs:
    # Only scrape services that have a metrics_port meta field.
    - source_labels: [__meta_consul_service_metadata_metrics_port]
      action: keep
      regex: (.+)
    
    # Replace the port in the address with the one from the metrics_port meta field.
    - source_labels: [__address__, __meta_consul_service_metadata_metrics_port]
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $${1}:$${2}
      target_label: __address__

    # Don't scrape -sidecar-proxy services that Consul sets up, otherwise we'll have duplicates.
    - source_labels: [__meta_consul_service]
      action: drop
      regex: (.+)-sidecar-proxy

    - source_labels: ['__meta_consul_service']
      regex: '(.*)'
      action: replace
      target_label: service_name

    - source_labels: ['__meta_consul_service_id']
      action: replace
      regex: '(.*)'
      target_label: service_id

    - source_labels: ['__meta_consul_address']
      action: replace
      regex: '(.*)'
      target_label: node_ip

    - source_labels: ['__meta_consul_node']
      action: replace
      regex: '(.*)'
      target_label: node_id

    - source_labels: [__meta_consul_service_metadata_external_source]
      action: replace
      regex: '(.*)'
      target_label: service_source

    # set metrics path to /metrics by default but override with meta=metrics_path
    - target_label:  __metrics_path__
      replacement: "/metrics"
      action: replace
    - source_labels: [__meta_consul_service_metadata_metrics_path]
      regex: '(.+)'
      target_label:  __metrics_path__
      replacement: $1
      action: replace
    

  - job_name: 'nomad_metrics'
    # Labels assigned to all metrics scraped from the targets.
    static_configs:
      - labels: {'cluster': 'dcotta'}
     
    nomad_sd_configs:
    - server: 'https://hez1.golden-dace.ts.net:4646'
      tls_config:
        insecure_skip_verify: true
    - server: 'https://hez2.golden-dace.ts.net:4646'
      tls_config:
        insecure_skip_verify: true

    relabel_configs:
    - source_labels: ['__meta_nomad_tags']
      regex: '(.*)metrics(.*)'
      action: keep

    - source_labels: ['__meta_nomad_service']
      regex: '(.*)'
      action: replace
      target_label: nomad_service

    - source_labels: ['__meta_nomad_namespace']
      action: replace
      regex: '(.*)'
      target_label: namespace

    - source_labels: ['__meta_nomad_service_id']
      action: replace
      regex: '(.*)'
      target_label: service_id

    - source_labels: ['__meta_nomad_node_id']
      action: replace
      regex: '(.*)'
      target_label: node_id


  - job_name: 'vault'
    metrics_path: "/v1/sys/metrics"
    scheme: https
    params:
      format: [ 'prometheus' ]
    authorization:
      credentials_file: /secrets/vault_token
    tls_config:
     insecure_skip_verify: true
     
    consul_sd_configs:
    - server: 'https://{{ env "NOMAD_IP_health" }}:8501' # well known consul https port
      tls_config:
        insecure_skip_verify: true

    relabel_configs:
    - source_labels: [__meta_consul_service]
      action: keep
      regex: vault

    - source_labels: [__meta_consul_address]
      regex: (.+)
      replacement: $${1}:8200
      target_label: __address__

  - job_name: 'consul'
    metrics_path: "/v1/agent/metrics"
    scheme: https
    params:
      format: [ 'prometheus' ]
    tls_config:
     insecure_skip_verify: true

    consul_sd_configs:
    - server: 'https://{{ env "NOMAD_IP_health" }}:8501' # well known consul https port
      tls_config:
        insecure_skip_verify: true

    relabel_configs:
    - source_labels: [__meta_consul_service]
      action: keep
      regex: consul

    - source_labels: [__meta_consul_address]
      regex: (.+)
      replacement: $${1}:8501
      target_label: __address__


remote_write:
- url: http://localhost:8001/api/v1/push
  send_native_histograms: true
EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

        args = [
          "--web.route-prefix=/",
          "--web.external-url=http://prometheus.traefik",
          "--config.file=/etc/prometheus/prometheus.yml",
          "--enable-feature=agent",
          "--web.enable-remote-write-receiver",
          "--enable-feature=exemplar-storage"
        ]

        ports = ["http"]
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 700
      }
    }
  }
}
