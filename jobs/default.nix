{ config, ... }:
let
  lib = (import ./lib) { };
in
{
  job."bye".group = config.job."whoami".group;
  job."whoami" = {
    group."whoami" = {
      #      network = {
      #        mode = "bridge";
      #        dynamicPorts = [
      #          { label = "http"; hostNetwork = "ts"; }
      #        ];
      #      };
      services = [{
        name = "aa";
        tags = [
          "traefik.enable=true"
          "traefik.http.routers.whoami.rule=PathPrefix(`/whoami`)"
          "traefik.http.middlewares.whoami-stripprefix.stripprefix.prefixes=/whoami"
          "traefik.http.routers.whoami.middlewares=whoami-stripprefix"
          "traefik.http.routers.whoami.entrypoints=websecure, web"
        ];
        port = "http";
        connect = {
          sidecarService = {
            proxy = let otlpPort = 9101; in {
              upstreams = [
                {
                  destinationName = "web-portfolio";
                  localBindPort = 8001;
                }
                {
                  destinationName = "tempo-otlp-grpc-mesh";
                  localBindPort = otlpPort;
                }
              ];
              config = lib.mkEnvoyProxyConfig {
                otlpService = "proxy-whoami";
                otlpUpstreamPort = otlpPort;
              };
            };
          };
        };
      }];
      task."whoami" = {
        driver = "docker";

        config = {
          image = "traefik/whoami";
          ports = [ "http" ];
          args = [
            "--port=\${NOMAD_PORT_http}"
          ];
        };
      };
    };
  };
}
