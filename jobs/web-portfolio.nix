let
  lib = import ./lib;
  tag = "sha-2713046";
in
lib.mkJob "web-portfolio" {

  priority = 50;

  update = {
    maxParallel = 1;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
  };

  group."web-portfolio" = {
    count = 2;
    network = {
      mode = "bridge";
      dynamicPorts = [{ label = "http"; }];
    };

    service."web-portfolio" = {
      connect.sidecarService = {
        proxy = let oltpPort = 9001; in {
          upstreams = [{
            destinationName = "tempo-otlp-grpc-mesh";
            localBindPort = oltpPort;
          }];
          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-web-portfolio";
            otlpUpstreamPort = oltpPort;
          };
        };
      };
      name = "web-portfolio-c";
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.rule=Host(`nico.dcotta.eu`)"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, web_public, websecure, websecure_public"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls.certresolver=lets-encrypt"
      ];
      port = "http";
    };
    task."web" = {
      driver = "docker";

      config = {
        image = "ghcr.io/cottand/web-portfolio:${tag}";
      };
      env = {
        PORT = "\${NOMAD_PORT_http}";
        HOST = "127.0.0.1";
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:9001";
        OTEL_SERVICE_NAME = "web-portfolio";
      };

      resources = {
        cpu = 70;
        memory = 60;
      };
    };
  };
}
