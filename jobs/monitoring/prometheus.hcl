job "prometheus" {
  datacenters = ["*"]
  type        = "service"
  priority    = 1

  group "monitoring" {
    count = 1

    network {
      mode = "bridge"
      dns {
        servers = [
          "10.10.0.1",
          "10.10.2.1",
          "10.10.4.1",
        ]
      }
      port "http" {
        to           = 9090
        host_network = "wg-mesh"
      }
    }

    constraint {
      attribute = "${attr.nomad.bridge.hairpin_mode}"
      value     = true
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size    = 256 # MB
      migrate = true
      sticky  = true
    }

    task "prometheus" {
      template {
        change_mode = "restart"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     30s
  evaluation_interval: 30s


scrape_configs:
  - job_name: 'nomad_metrics'
    # Labels assigned to all metrics scraped from the targets.
    static_configs:
      - labels: {'cluster': 'dcotta'}
    nomad_sd_configs:
    - server: 'https://miki.mesh.dcotta.eu:4646'
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
      target_label: nomad_node_id


#    scrape_interval: 20s
#    metrics_path: /v1/metrics
#    params:
#      format: ['prometheus']

  - job_name: 'nomad_sys_metrics'
    metrics_path: /v1/metrics
    scheme: https
    tls_config:
      insecure_skip_verify: true
    params:
      format: ['prometheus']
    static_configs:
      - targets: [ 'ziggy.mesh.dcotta.eu:4646', 'maco.mesh.dcotta.eu:4646','cosmo.mesh.dcotta.eu:4646', 'bianco.mesh.dcotta.eu:4646', 'elvis.mesh.dcotta.eu:4646', 'ari.mesh.dcotta.eu:4646', 'miki.mesh.dcotta.eu:4646' ]

  # - job_name: 'vault'
  #   metrics_path: "/v1/sys/metrics"
  #   scheme: https
  #   tls_config:
  #      ca_file: your_ca_here.pem
  #   bearer_token: "your_vault_token_here"
  #   static_configs:
  #   - targets: ['maco.mesh.dcotta.eu:8200']

remote_write:
- url: http://mimir.traefik/api/v1/push
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

      service {
        name     = "prometheus"
        provider = "nomad"
        port     = "http"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
        tags = [
          "metrics",
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file",
        ]
      }
    }
  }
}
