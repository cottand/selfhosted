{ version ? "d43fc34"
, ...
}:
let
  lib = (import ../../../jobs/lib) { };
  name = builtins.baseNameOf ./.;
  cpu = 100;
  mem = 200;
  ports = {
    http = 8080;
    grpc = 8081;
    upDb = 5432;
  };
  resources = {
    cpu = cpu;
    memoryMB = mem;
    memoryMaxMB = builtins.ceil (2 * mem);
  };
  sidecarResources = lib.mkSidecarResourcesWithFactor 0.15 resources;
  otlpPort = 9001;
in
lib.mkJob name {
  type = "batch";
  periodic = {
    enabled = true;
    prohibitOverlap = true;
    specType = "cron";
    specs = [ "@daily" ];
  };

  meta.version = version;
  group.${name} = {
    network = {
      inherit (lib.defaults.dns) servers;

      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; hostNetwork = "ts"; }
      ];
      reservedPorts = [ ];
    };

    volumes."ca-certificates" = rec {
      name = "ca-certificates";
      type = "host";
      readOnly = true;
      source = name;
    };
    service."${name}-http" = rec {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-${name}-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      port = toString ports.http;
      meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      meta.metrics_path = "/metrics";
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
      ];
    };
    service."${name}-grpc" = {
      connect.sidecarService.proxy.upstream."services-go-grpc".localBindPort = ports.grpc;
      connect.sidecarService.proxy.config = lib.mkEnvoyProxyConfig {
        otlpService = "proxy-${name}-grpc";
        otlpUpstreamPort = otlpPort;
        extra.local_request_timeout_ms = 5 * 60 * 1000;
        extra.protocol = "grpc";
      };
      connect.sidecarTask.resources = sidecarResources;
      port = toString ports.grpc;
    };

    task.${name} = {
      inherit resources;
      driver = "docker";
      config = {
        image = "ghcr.io/cottand/selfhosted/${name}:${version}";
      };
      env = {
        HTTP_HOST = lib.localhost;
        HTTP_PORT = toString ports.http;
        GRPC_PORT = toString ports.grpc;
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:${toString otlpPort}";
        OTEL_SERVICE_NAME = name;
        DCOTTA_COM_VERSION = version;
      };
      volumeMounts = [{
        volume = "ca-certificates";
        destination = "/etc/ssl/certs";
        readOnly = true;
        propagationMode = "host-to-task";
      }];
    };
  };
}
