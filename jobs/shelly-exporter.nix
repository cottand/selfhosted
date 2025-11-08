{ util, time, ... }:
let
  name = "shelly-exporter";
  version = "latest";
  cpu = 100;
  mem = 100;
  ports = {
    http = 8000;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
{
  job."shelly-exporter" = {
    datacenters = [ "london-home" ];

    group."${name}" = {
      count = 1;
      network = {
        mode = "bridge";
        port."metrics".hostNetwork = "ts";
      };

      service."${name}-metrics" = rec  {
        connect.sidecarService = {
          proxy = {
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        # TODO implement http healthcheck
        port = toString ports.http;
        meta = {
          metrics_port = "\${NOMAD_HOST_PORT_metrics}";
          metrics_path = "/probe";
        };
        checks = [{
          expose = true;
          name = "metrics";
          port = "metrics";
          type = "http";
          path = meta.metrics_path;
          interval = 10 * time.second;
          timeout = 3 * time.second;
        }];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}-http.entrypoints=web,websecure"
          "traefik.http.routers.${name}-http.tls=true"
        ];
      };
      task."${name}" = {
        driver = "docker";
        vault = { };

        config = {
          # https://github.com/webdevops/shelly-plug-exporter/tree/main
          image = "webdevops/shelly-plug-exporter:${version}";
          args = [
            "--server.bind=localhost:${toString ports.http}"
          ];
        };
        env."SHELLY_HOST_SHELLYPLUSES" = "192.168.50.103,192.168.50.104";
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);
        };
      };
    };
  };
}
