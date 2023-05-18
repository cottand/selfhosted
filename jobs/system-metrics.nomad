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
                command = "local/node_exporter-1.5.0.linux-amd64/node_exporter"
                args    = [
                    "--web.listen-address=:${NOMAD_PORT_exporter}"
                ]
            }

            artifact {
                source      = "https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz"
                destination = "local"
                options {
                    checksum = "sha256:af999fd31ab54ed3a34b9f0b10c28e9acee9ef5ac5a5d5edfdde85437db7acbb"
                }
            }

            resources {
                cpu    = 500
                memory = 256
            }
        }
    }
}