# The Prometheus Node Exporter needs access to the proc filesystem which is not
# mounted into the exec jail, so it requires the raw_exec driver to run.

job "system-metrics" {
    datacenters = ["dc1"]
    type        = "system"
    priority    = 1

    group "system-metrics" {
        network {
            mode = "bridge"
            port "exporter" {
                host_network = "vpn"
            }
        }

        service {
            provider = "nomad"
            name     = "node-exporter"
            port     = "exporter"
            tags     = [
                "metrics",
            ]
            check {
                name     = "alive"
                type     = "tcp"
                interval = "10s"
                timeout  = "2s"
            }
        }

        task "node-exporter" {
            driver = "raw_exec"

            config {
                command = "local/node_exporter-1.6.0.linux-amd64/node_exporter"
                args    = [
                    "--web.listen-address=:${NOMAD_PORT_exporter}"
                ]
            }

            artifact {
                source      = "https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz"
                destination = "local"
                options {
                    checksum = "sha256:0b3573f8a7cb5b5f587df68eb28c3eb7c463f57d4b93e62c7586cb6dc481e515"
                }
            }

            resources {
                cpu    = 500
                memory = 256
            }
        }
    }
}