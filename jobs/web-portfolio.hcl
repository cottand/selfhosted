variable "tag" {
  type    = string
  default = "sha-2713046"
}

variable "otlp_upstream" {
  type    = number
  default = 19199
}

job "web-portfolio" {
  priority = 50

  update {
    max_parallel = 1
    auto_revert  = true
    auto_promote = true
    canary       = 1
  }

  group "web-portfolio" {
    count = 2
    network {
      mode = "bridge"
      port "http" {}
    }
    service {
      task = "web"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "tempo-otlp-grpc-mesh"
              local_bind_port  = var.otlp_upstream
            }
            config {
              protocol           = "http"
              envoy_tracing_json = <<EOF
{
   "http": {
            "name": "envoy.tracers.opentelemetry",
            "typed_config": {
                "@type": "type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig",
                "grpc_service": {
                    "envoy_grpc": {
                        "cluster_name": "opentelemetry_collector"
                    },
                    "timeout": "0.250s"
                },
                "service_name": "envoy-${NOMAD_GROUP_NAME}"
            }
        }
}
  EOF

              envoy_extra_static_clusters_json = <<EOF
{
    "name": "opentelemetry_collector",
    "type": "STRICT_DNS",
    "lb_policy": "ROUND_ROBIN",
    "typed_extension_protocol_options": {
        "envoy.extensions.upstreams.http.v3.HttpProtocolOptions": {
            "@type": "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
            "explicit_http_config": {
                "http2_protocol_options": {}
            }
        }
    },
    "load_assignment": {
        "cluster_name": "opentelemetry_collector",
        "endpoints": [
            {
                "lb_endpoints": [
                    {
                        "endpoint": {
                            "address": {
                                "socket_address": {
                                    "address": "127.0.0.1",
                                    "port_value": ${var.otlp_upstream}
                                }
                            }
                        }
                    }
                ]
            }
        ]
    }
}
EOF
            }
          }
        }
      }
      name = "web-portfolio-c"
      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.connect=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.rule=Host(`nico.dcotta.eu`)",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.entrypoints=web, web_public, websecure, websecure_public",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls=true",
        "traefik.http.routers.${NOMAD_GROUP_NAME}.tls.certresolver=lets-encrypt"
      ]
      port = "http"
    }
    task "web" {
      driver = "docker"

      config {
        image = "ghcr.io/cottand/web-portfolio:${var.tag}"
      }
      env {
        PORT = "${NOMAD_PORT_http}"
        HOST = "127.0.0.1"
      }


      resources {
        cpu    = 70
        memory = 60
      }
      template {
        destination = "config/.env"
        change_mode = "restart"
        env         = true
        data        = <<-EOF
{{ range service "tempo-otlp-grpc" }}
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://{{ .Address }}:{{ .Port }}
OTEL_SERVICE_NAME="web-portfolio"
{{ end }}
EOF
      }
    }
  }
}