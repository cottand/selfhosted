{ util, time, defaults, ... }:
let
  cpu = 100;
  mem = 256;
  ports = {
    http = 5212;
    upDb = 5432;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = "127.0.0.1";
in
{
  job."cloudreve" = {
    group."cloudreve" = {
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

      ephemeralDisk = {
        size = 1000;
        migrate = true;
        sticky = true;
      };

      service."cloudreve" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-cloudreve";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "cloudreve-health";
          port = "health";
          type = "http";
          path = "/";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.cloudreve.entrypoints=web, websecure"
          "traefik.http.routers.cloudreve.tls=true"
        ];
      };

      task."cloudreve" = {
        vault = { };
        driver = "docker";
        config = {
          image = "cloudreve/cloudreve:latest";
          args = ["-c" "/local/conf.ini"];
          volumes = [ "local/conf.ini:/cloudreve/data/conf.ini" ];
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = mem * 2;
        };

        templates = [
          {
            destination = "local/conf.ini";
            changeMode = "restart";
            data = ''
              [System]
              Listen = `${bind}:${toString ports.http}`
              ProxyHeader = `X-Forwarded-For`

              [Database]
              Type = postgres
              {{ with secret "secret/data/nomad/job/roach/users/cloudreve" }}
              Host = `${bind}`

              DatabaseURL = `host=${bind} user=cloudreve dbname=cloudreve port=${toString ports.upDb} sslmode=verify-ca sslcert=/secrets/client.cloudreve.crt sslkey=/secrets/client.cloudreve.key sslrootcert=/secrets/ca.crt`
              {{ end }}
            '';
          }
          {
            destination = "/secrets/client.cloudreve.key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/cloudreve"}}{{.Data.data.key}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/client.cloudreve.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/cloudreve"}}{{.Data.data.chain}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/ca.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/cloudreve"}}{{.Data.data.ca}}{{end}}
            '';
            perms = "0600";
          }
        ];
      };
    };
  };
}
