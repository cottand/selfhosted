let
  lib = import ./lib;
  tag = "sha-2713046";
in
lib.mkJob "web-portfolio" {

  priority = 50;

  update = {
    max_parallel = 1;
    auto_revert = true;
    auto_promote = true;
    canary = 1;
  };

  group."web-portfolio" = {
    count = 2;
    network = {
      mode = "bridge";
      port."http" = { };
    };

    service."web-portfolio" = {
      connect.sidecar_service = {
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
      };


      resources = {
        cpu = 70;
        memory = 60;
      };
      template = {
        destination = "config/.env";
        change_mode = "restart";
        env = true;
        data = ''
          {{ range service "tempo-otlp-grpc" }}
          OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://{{ .Address }}:{{ .Port }}
          OTEL_SERVICE_NAME="web-portfolio"
          {{ end }}
        '';
      };
    };
  };
}
