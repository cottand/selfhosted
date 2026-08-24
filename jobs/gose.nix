{ util, time, defaults, ... }:
let
  cpu = 100;
  mem = 128;
  ports = {
    http = 8080;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  host = "share.dcotta.com";
in
{
  job."gose" = {
    group."gose" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      service."gose" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-gose";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "gose-health";
          port = "health";
          type = "http";
          path = "/";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.gose.tls=true"
          "traefik.http.routers.gose.entrypoints=web,websecure,cloudflared"
          "traefik.http.routers.gose.rule=Host(`${host}`)"
        ];
      };

      task."gose" = {
        vault = { };
        driver = "docker";
        config = {
          image = "ghcr.io/stv0g/gose:v0.4.0";
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = mem * 2;
        };

        env = {
          GOSE_LISTEN = ":${toString ports.http}";
          GOSE_BASE_URL = "https://${host}";
          GOSE_SETUP_BUCKET = "false";
          GOSE_SETUP_CORS = "false";
          GOSE_SETUP_LIFECYCLE = "false";
        };

        templates = [{
          destination = "secrets/env";
          changeMode = "restart";
          env = true;
          data = ''
            {{ with secret "secret/data/nomad/job/gose/b2" }}
            GOSE_ACCESS_KEY={{ .Data.data.keyID }}
            GOSE_SECRET_KEY={{ .Data.data.applicationKey }}
            GOSE_BUCKET={{ .Data.data.bucket }}
            GOSE_ENDPOINT={{ .Data.data.endpoint }}
            GOSE_REGION={{ .Data.data.region }}
            {{ end }}
          '';
        }];
      };
    };
  };
}
