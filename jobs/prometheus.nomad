job "prometheus" {
    datacenters = ["dc1"]
    type        = "service"
    priority    = 1

    group "monitoring" {
        count = 1

        network {
            mode = "bridge"
            port "http" {
                to           = 9090
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
            size    = 128 # MB
            migrate = true
            sticky  = true
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
  - job_name: 'nomad_metrics'
    nomad_sd_configs:
    - server: 'http://cosmo.vpn.dcotta.eu:4646'
    relabel_configs:
    - source_labels: ['__meta_nomad_tags']
      regex: '(.*)metrics(.*)'
      action: keep
    - source_labels: ['__meta_nomad_service']
      regex: '(.*)'
      action: replace
      target_label: nomad_service
#
#    scrape_interval: 20s
#    metrics_path: /v1/metrics
#    params:
#      format: ['prometheus']
  - job_name: 'nomad_sys_metrics'
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    static_configs:
      - targets: [ 'maco.vpn.dcotta.eu:4646','cosmo.vpn.dcotta.eu:4646', 'ari.vpn.dcotta.eu:4646' ]
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
