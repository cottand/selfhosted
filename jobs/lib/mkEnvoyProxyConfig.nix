{ otlpService
, otlpUpstreamPort
, otlpUpstreamHost ? "127.0.0.1"
, protocol ? "http"
, extra ? { inherit protocol; }
,
}:
{
  envoy_listener_tracing_json = builtins.toJSON {
    "@type" = "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager.Tracing";
    custom_tags = [
      { request_header.default_value = ""; request_header.name = "x-custom-traceid"; tag = "custom_header"; }
      { environment.name = "NOMAD_ALLOC_ID"; tag = "alloc_id"; }
    ];
    provider = {
      name = "envoy.tracers.opentelemetry";
      typed_config = {
        "@type" = "type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig";
        grpc_service = {
          envoy_grpc.cluster_name = "opentelemetry_collector";
          timeout = "1.500s";
        };
        service_name = otlpService;
      };
    };
    # see https://github.com/hashicorp/consul/pull/20973
    spawn_upstream_span = true;
  };



  envoy_extra_static_clusters_json = ''
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
                                        "address": "${otlpUpstreamHost}",
                                        "port_value": ${toString otlpUpstreamPort}
                                    }
                                }
                            }
                        }
                    ]
                }
            ]
        }
    }
  '';
} // extra
