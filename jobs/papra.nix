{ util, time, defaults, ... }:
let
  resources = {
    cpu = 100;
    memory = 256;
    memoryMax = 512;
  };
  libsqlResources = {
    cpu = 100;
    memory = 128;
    memoryMax = 256;
  };
  ports = {
    http = 1221;
    libsql = 8080;
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 resources;
  otlpPort = 9001;
  bind = util.localhost;

  restart = {
    attempts = 3;
    interval = 10 * time.minute;
    delay = 15 * time.second;
    mode = "delay";
  };
in
{
  job."papra" = {

    group."papra" = {
      inherit restart;
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };

      service."papra-http" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "papra-libsql"; localBindPort = ports.libsql; }
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-papra-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "papra-health";
          port = "health";
          type = "http";
          path = "/";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.papra-http.entrypoints=web,websecure"
          "traefik.http.routers.papra-http.rule=Host(`papra-http.tfk.nd`)"
          "traefik.http.routers.papra-http.tls=true"
        ];
      };

      task."papra" = {
        vault = { };
        driver = "docker";
        config = {
          image = "ghcr.io/papra-hq/papra:latest";
        };

        inherit resources;

        env = {
          DOCUMENT_STORAGE_DRIVER = "s3";
          DOCUMENT_STORAGE_S3_FORCE_PATH_STYLE = "true";
          APP_BASE_URL = "https://papra-http.tfk.nd";

          AUTH_IS_REGISTRATION_ENABLED = "false";
          AUTH_SHOW_LEGAL_LINKS = "false";
        };

        templates = [{
          destination = "secrets/env";
          changeMode = "restart";
          env = true;
          #            DATABASE_AUTH_TOKEN={{ .Data.data.dbToken }}
          #            DATABASE_URL=file:./db.sqlite
          data = ''
            {{ with secret "secret/data/nomad/job/papra/auth" }}
            AUTH_SECRET={{ .Data.data.secret }}
            {{ end }}

            DATABASE_URL=http://${bind}:${toString ports.libsql}

            {{ with secret "secret/data/nomad/job/papra/b2" }}
            DOCUMENT_STORAGE_S3_ACCESS_KEY_ID={{ .Data.data.keyID }}
            DOCUMENT_STORAGE_S3_SECRET_ACCESS_KEY={{ .Data.data.applicationKey }}
            DOCUMENT_STORAGE_S3_BUCKET_NAME={{ .Data.data.bucket }}
            DOCUMENT_STORAGE_S3_ENDPOINT=https://s3.us-east-005.backblazeb2.com
            DOCUMENT_STORAGE_S3_REGION=us-east-005
            {{ end }}


            # Whether to enable encryption for documents.
            # DOCUMENT_STORAGE_ENCRYPTION_IS_ENABLED=false
            # Key encryption keys (KEKs) used to encrypt the document encryption key
            # (DEK), as 32-byte hex strings, you can generate one using the command
            # `openssl rand -hex 32`.

            # Formats:
            # - Single key:
            # `0deba5534bd70548de92d1fd4ae37cf901cca3dc20589b7e022ddb680c98e50c` (will be
            # assigned version `1`)
            # - Multiple keys: `1:<key1>,2:<key2>`
            #  - The key with the highest version will be used to encrypt new DEKs, others will be
            # used to decrypt existing DEKs
            #   - Versions must be unique and can be any
            # alphabetically sortable string
            #   - The order of the version:key pair is
            # not important.
            # DOCUMENT_STORAGE_DOCUMENT_KEY_ENCRYPTION_KEYS=
          '';
        }];
      };
    };

    group."papra-libsql" = {
      inherit restart;
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };

      ephemeralDisk = {
        size = 2000;
        migrate = true;
        sticky = true;
      };

      service."papra-libsql" = {
        port = toString ports.libsql;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-papra-libsql";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = util.mkResourcesWithFactor 0.15 libsqlResources;
        };

        checks = [{
          expose = true;
          name = "libsql-health";
          port = "health";
          type = "http";
          path = "/health";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];
      };

      task."papra-libsql" = {
        vault = { };
        driver = "docker";
        config = {
          image = "ghcr.io/tursodatabase/libsql-server:latest";
          command = "sqld";
          args = [
            "--enable-bottomless-replication"
          ];
        };

        resources = libsqlResources;

        templates = [{
          destination = "secrets/env";
          changeMode = "restart";
          env = true;
          #            SQLD_AUTH_JWT_KEY={{ .Data.data.dbToken }}
          data = ''
            {{ with secret "secret/data/nomad/job/papra/auth" }}
            {{ end }}

            {{ with secret "secret/data/nomad/job/papra/b2-db" }}
            LIBSQL_BOTTOMLESS_BUCKET={{ .Data.data.bucket }}
            LIBSQL_BOTTOMLESS_ENDPOINT=https://{{ .Data.data.endpoint }}
            LIBSQL_BOTTOMLESS_AWS_ACCESS_KEY_ID={{ .Data.data.keyID }}
            LIBSQL_BOTTOMLESS_AWS_SECRET_ACCESS_KEY={{ .Data.data.applicationKey }}
            LIBSQL_BOTTOMLESS_AWS_DEFAULT_REGION={{ .Data.data.region }}
            {{ end }}
          '';
        }];
      };
    };
  };
}
