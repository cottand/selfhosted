job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "monitoring" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        to = 9090
        host_network = "vpn"
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size = 128 # MB
      migrate = true
      sticky = true
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"

        data = <<EOH
---
global:
  scrape_interval:     30s
  evaluation_interval: 30s

scrape_configs:
#{{ range nomadService "traefik-metrics" }}
#  - job_name: 'traefik'
#    static_configs:
#      - targets: [ '{{ .Address }}:{{ .Port }}' ]
#{{ end }}
#{{ range nomadService "dns-metrics" }}
#  - job_name: 'blocky'
#    static_configs:
#      - targets: [ '{{ .Address }}:{{ .Port }}' ]
#{{ end }}
  - job_name: 'nomad_metrics'
    nomad_sd_configs:
    - server: 'http://{{ env "NOMAD_IP_http" }}:4646'
#      services: ['nomad-client', 'nomad']

#    relabel_configs:
#    - source_labels: ['__meta_nomad_tags']
#      regex: '(.*)http(.*)'
#      action: keep

#    scrape_interval: 20s
#    metrics_path: /v1/metrics
#    params:
#      format: ['prometheus']
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
          "--web.external-url=https://web.vps.dcotta.eu/prometheus",
          "--config.file=/etc/prometheus/prometheus.yml"
        ]

        ports = ["http"]
      }

      service {
        name = "prometheus"
        provider = "nomad"
        port = "http"

        tags = [
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
