{ util, ... }: {
  job."whoami" = {
    group."whoami" = {
      network = {
        mode = "bridge";
        port."http".hostNetwork = "ts";
      };
      service."whoami" = {
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
              config = util.mkEnvoyProxyConfig {
                otlpService = "proxy-whoami";
                otlpUpstreamPort = otlpPort;
              };
            };
          };
        };
      };
      task."whoami" = {
        driver = "docker";

        config = {
          images = "traefik/whoami";
          ports = [ "http" ];
          args = [
            "--port=\${NOMAD_PORT_http}"
          ];
        };
      };
    };
  };
}
