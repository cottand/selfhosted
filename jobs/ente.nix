{ util, time, defaults, ... }:
let
  resources = {
    cpu = 100;
    memory = 200;
    memoryMax = 500;
  };

  ports = {
    server = 8080;
    web = 3000;
    upDb = 5432;
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 resources;


  otlpPort = 9001;
  bind = "127.0.0.1";

  # Web addresses
  enteWebUrl = "https://ente.traefik";
  enteApiUrl = "https://ente-api.traefik";
in
{
  job."ente" = {
    type = "service";

    ui = {
      description = "Ente Photos - Self-hosted Google Photos alternative";
      links = [
        { label = "Ente Web"; url = enteWebUrl; }
        { label = "Ente API"; url = enteApiUrl; }
      ];
    };

    group."ente" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."healthz".hostNetwork = "ts";
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      update = {
        maxParallel = 1;
        minHealthyTime = 30 * time.second;
        healthyDeadline = 5 * time.minute;
        autoRevert = true;
        autoPromote = true;
        canary = 1;
      };

      # Ente Server (API)
      service."ente-server" = {
        port = toString ports.server;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-ente-server-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "healthz";
          port = "healthz";
          type = "http";
          path = "/ping";
          interval = 30 * time.second;
          timeout = 5 * time.second;
          checkRestart = {
            limit = 3;
            grace = 30 * time.second;
            ignoreWarnings = false;
          };
          task = "ente-server";
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.ente-api.middlewares=vpn-whitelist@file"
          "traefik.http.routers.ente-api.entrypoints=web, websecure"
          "traefik.http.routers.ente-api.tls=true"
          "traefik.http.routers.ente-api.rule=Host(`ente-api.traefik`)"
        ];
      };

      # Ente Web Client
      service."ente-web" = {
        port = toString ports.web;
        connect = {
          sidecarService.proxy = {
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-ente-web-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "web-health";
          port = toString ports.web;
          type = "http";
          path = "/";
          interval = 30 * time.second;
          timeout = 5 * time.second;
          task = "ente-web";
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.ente.entrypoints=web, websecure"
          "traefik.http.routers.ente.tls=true"
          "traefik.http.routers.ente.rule=Host(`ente.traefik`)"
        ];
      };

      # Ente Server Task
      task."ente-server" = {
        vault.env = true;
        driver = "docker";
        config = {
          image = "ghcr.io/ente-io/server:latest";
          ports = [ "server" ];
        };

        inherit resources;

        env = builtins.mapAttrs (_: toString) {
          ENTE_DB_HOST = "${bind}";
          ENTE_DB_PORT = ports.upDb;
          ENTE_DB_NAME = "ente";
          ENTE_DB_SSLMODE = "require";
          HTTP_HOST = "0.0.0.0";
          HTTP_PORT = ports.server;
        };

        templates = [
          {
            destination = "local/museum.yaml";
            changeMode = "restart";
            data = ''
              db:
                host: ${bind}
                port: ${toString ports.upDb}
                name: ente
                user: ente
                password: {{ with secret "secret/data/nomad/job/roach/users/ente" }}{{ .Data.data.password }}{{ end }}
                sslmode: require
              
              # S3 Configuration - using existing SeaweedFS
              s3:
                hot_storage:
                  primary: seaweed-s3
                
                seaweed-s3:
                  key: ""
                  secret: ""
                  endpoint: https://s3.traefik
                  region: us-east-1
                  bucket: ente
                  
              # Server configuration
              server:
                host: 0.0.0.0
                port: ${toString ports.server}
                
              # JWT and encryption keys
              key:
                encryption: {{ with secret "secret/data/services/ente" }}{{ .Data.data.encryption_key }}{{ end }}
                jwt: {{ with secret "secret/data/services/ente" }}{{ .Data.data.jwt_secret }}{{ end }}
            '';
          }
          {
            destination = "/secrets/client.ente.key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.key}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/client.ente.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.chain}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/ca.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.ca}}{{end}}
            '';
            perms = "0600";
          }
        ];
      };

      # Ente Web Task
      task."ente-web" = {
        driver = "docker";
        config = {
          image = "ghcr.io/ente-io/web:latest";
          ports = [ "web" ];
        };

        inherit resources;

        env = builtins.mapAttrs (_: toString) {
          NEXT_PUBLIC_ENTE_ENDPOINT = enteApiUrl;
          NEXT_PUBLIC_ENTE_ALBUMS_ENDPOINT = enteApiUrl;
        };
      };
    };
  };
}
