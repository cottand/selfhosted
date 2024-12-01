resource "consul_config_entry" "service_defaults_grpc" {
  kind = "service-defaults"
  name = "grpc"
  config_json = jsonencode({
    LocalRequestTimeoutMs = 60 * 1000 # default 15s
    Expose = {}
    MeshGateway = {}
    TransparentProxy = {}
  })
}
resource "consul_config_entry" "proxy_defaults" {
  kind = "proxy-defaults"
  name = "global"
  config_json = jsonencode({
    #     local_request_timeout_ms = 60 * 1000 # default 15s
    LocalRequestTimeoutMs = 60 * 1000 # default 15s
    AccessLogs = {}
    Expose = {}
    MeshGateway = {}
    TransparentProxy = {}
  })
}

#   config_json = jsonencode({
#     AccessLogs       = {}
#     Expose           = {}
#     MeshGateway      = {}
#     TransparentProxy = {}
#     Config = {


# resource "consul_config_entry" "proxy_defaults" {
#   kind = "proxy-defaults"
#   name = "global"

#   config_json = jsonencode({
#     AccessLogs       = {}
#     Expose           = {}
#     MeshGateway      = {}
#     TransparentProxy = {}
#     Config = {
#               envoy_tracing_json = <<EOF
# {
#    "http": {
#             "name": "envoy.tracers.opentelemetry",
#             "typed_config": {
#                 "@type": "type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig",
#                 "grpc_service": {
#                     "envoy_grpc": {
#                         "cluster_name": "opentelemetry_collector"
#                     },
#                     "timeout": "0.250s"
#                 },
#                 "service_name": "envoy-proxy"
#             }
#         }
# }
#   EOF

#                    envoy_extra_static_clusters_json = <<EOF
# {
#     "name": "opentelemetry_collector",
#     "type": "STRICT_DNS",
#     "lb_policy": "ROUND_ROBIN",
#     "typed_extension_protocol_options": {
#         "envoy.extensions.upstreams.http.v3.HttpProtocolOptions": {
#             "@type": "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
#             "explicit_http_config": {
#                 "http2_protocol_options": {}
#             }
#         }
#     },
#     "load_assignment": {
#         "cluster_name": "opentelemetry_collector",
#         "endpoints": [
#             {
#                 "lb_endpoints": [
#                     {
#                         "endpoint": {
#                             "address": {
#                                 "socket_address": {
#                                     "address": "127.0.0.1",
#                                     "port_value": 19199
#                                 }
#                             }
#                         }
#                     }
#                 ]
#             }
#         ]
#     }
# }
# EOF
#     }
#   })
# }