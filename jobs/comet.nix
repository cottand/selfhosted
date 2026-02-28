{ util, time, defaults, ... }:
let
  version = "latest";
  cpu = 200;
  mem = 512;
  ports = {
    http = 8000;
    upDb = 5432;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  bind = "127.0.0.1";
in
{
  job."comet" = {
    type = "service";
    group."comet" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";

        port."http" = {
          static = ports.http;
          to = ports.http;
        };
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      service."comet" = {
        port = "http";
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
            ];
          };

          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          name = "health";
          type = "http";
          path = "/health";
          interval = 30 * time.second;
          timeout = 10 * time.second;
          checkRestart = {
            limit = 3;
            grace = 30 * time.second;
            ignoreWarnings = false;
          };
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        ];
      };

      task."comet" = {
        vault.env = true;
        driver = "docker";
        config = {
          image = "g0ldyy/comet:${version}";
          ports = [ "http" ];
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (1.5 * mem);
        };

        env = {
          DATABASE_TYPE = "postgresql";
          DATABASE_URL = "postgresql://comet@${bind}:${toString ports.upDb}/comet?sslmode=verify-ca&sslcert=/secrets/client.comet.crt&sslkey=/secrets/client.comet.key&sslrootcert=/secrets/ca.crt";
        };

        templates = [
          {
            destination = "/secrets/client.comet.key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/comet"}}{{.Data.data.key}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/client.comet.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/comet"}}{{.Data.data.chain}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/ca.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/comet"}}{{.Data.data.ca}}{{end}}
            '';
            perms = "0600";
          }
        ];
      };
    };
  };
}