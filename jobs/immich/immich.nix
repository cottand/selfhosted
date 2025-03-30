{ util, time, defaults, ... }:
let
  lib = (import ../lib) { };
  version = "v1.130.3";
  domain = "immich.dcotta.com";
  ports = {
    http = 8080;
    ml-http = 8081;
    upS3 = 3333;
    redis = 6379;
    postgres = 5432;
    metrics = 9091;
    services-mertrics = 9092;
  };
  resources = rec {
    cpu = 200;
    memory = 1024;
    memoryMax = 2 * memory;
  };
  resources-ml = rec {
    cpu = 420;
    memory = 1024;
    memoryMax = 2 * memory;
  };
  sidecarResources = util.mkResourcesWithFactor 0.18 resources;
  otlpPort = 9001;
  bind = lib.localhost;
  restart = {
    attempts = 4;
    interval = 10 * lib.minutes;
    delay = 20 * time.second;
    mode = "delay";
  };
in
{
  job."immich" = {
    affinities = [{
      attribute = "distinct_hosts";
      operator = "is";
      value = "true";
      weight = 100;
    }];

    # TODO reenable when healthchecks
    update = {
      maxParallel = 1;
      autoRevert = true;
      canary = 0;
    };

    group."immich" = {
      inherit restart;
      count = 1;
      network = {
        mode = "bridge";
        port."health".hostNetwork = "ts";
        port."metrics".hostNetwork = "ts";
        port."services-metrics".hostNetwork = "ts";
      };
      volume."immich-pictures" = {
        name = "immich-pictures";
        type = "csi";
        readOnly = false;
        source = "immich-pictures";
        accessMode = "single-node-writer";
        attachmentMode = "file-system";
      };
      service."immich-http" = {
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
              { destinationName = "immich-postgres"; localBindPort = ports.postgres; }
              { destinationName = "immich-redis"; localBindPort = ports.redis; }
              { destinationName = "immich-ml-http"; localBindPort = ports.ml-http; }
            ];
            config = lib.mkEnvoyProxyConfig {
              otlpService = "proxy-immich-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        # TODO implement http healthcheck
        port = toString ports.http;
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.immich-http.entrypoints=web,websecure"
          "traefik.http.routers.immich-http.rule=Host(`immich-http.tfk.nd`)"
          "traefik.http.routers.immich-http.tls=true"

          "traefik.http.routers.immich-http-pub.entrypoints=websecure_public"
          "traefik.http.routers.immich-http-pub.rule=Host(`${domain}`)"
          "traefik.http.routers.immich-http-pub.tls=true"
        ];
      };
      service."immich-metrics" = {
        connect.sidecarService.proxy.config = util.mkEnvoyProxyConfig {
          otlpService = "proxy-immich-http";
          otlpUpstreamPort = otlpPort;
          protocol = "http";
        };
        connect.sidecarTask.resources = sidecarResources;
        # TODO implement http healthcheck
        port = toString ports.metrics;
        meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        meta.metrics_path = "/metrics";
        checks = [{
          expose = true;
          name = "metrics";
          port = "metrics";
          type = "http";
          path = "/metrics";
          interval = 30 * time.second;
          timeout = 5 * time.second;
          checkRestart = {
            limit = 3;
            grace = 70 * time.second;
            ignoreWarnings = false;
          };
        }];
      };
      service."immich-services-metrics" = {
        connect.sidecarService.proxy.config = util.mkEnvoyProxyConfig {
          otlpService = "proxy-immich-http";
          otlpUpstreamPort = otlpPort;
          protocol = "http";
        };
        connect.sidecarTask.resources = sidecarResources;
        # TODO implement http healthcheck
        port = toString ports.services-mertrics;
        meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        meta.metrics_path = "/metrics";
        checks = [{
          expose = true;
          name = "services-metrics";
          port = "services-metrics";
          type = "http";
          path = "/metrics";
          interval = 30 * time.second;
          timeout = 5 * time.second;
          checkRestart = {
            limit = 3;
            grace = 70 * time.second;
            ignoreWarnings = false;
          };
        }];
      };
      task."immich" = {
        driver = "docker";
        vault = { };

        config = {
          image = "ghcr.io/immich-app/immich-server:${version}";
          image_pull_timeout = "10m";
        };
        env = {
          IMMICH_PORT = toString ports.http;
          IMMICH_HOST = bind;
          DB_DATABASE_NAME = "immich";
          DB_HOSTNAME = lib.localhost;
          DB_PORT = toString ports.postgres;
          REDIS_HOSTNAME = lib.localhost;
          REDIS_PORT = toString ports.redis;
          IMMCH_ENV = "production";
          IMMICH_MEDIA_LOCATION = "/vol/immich-pictures";
          IMMICH_CONFIG_FILE = "/local/config.json";
          IMMICH_TELEMETRY_INCLUDE = "all";
          IMMICH_API_METRICS_PORT = toString ports.metrics;
          IMMICH_MICROSERVICES_METRICS_PORT = toString ports.services-mertrics;
          NODE_EXTRA_CA_CERTS = "/local/ca.crt";


          OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:${toString otlpPort}";
          OTEL_TRACES_EXPORTER = "otlp";
          OTEL_SERVICE_NAME = "immich";
          OTEL_SDK_DISABLED = "false";
        };
        inherit resources;
        volumeMounts = [
          {
            volume = "immich-pictures";
            destination = "/vol/immich-pictures";
            readOnly = false;
          }
        ];
        templates = [
          {
            destination = "config/.env";
            changeMode = "restart";
            env = true;
            data = ''
              {{ with nomadVar "nomad/jobs/immich" }}
              TYPESENSE_API_KEY="{{ .typesense_api_key }}"
              DB_PASSWORD="{{ .db_password }}"
              DB_USERNAME={{ .db_user }}
              {{ end -}}

              IMMICH_SERVER_URL=http://{{ env "NOMAD_IP_server" }}:{{ env "NOMAD_HOST_PORT_server" }}

              ENABLE_TYPESENSE="false"
            '';
          }
          {
            destination = "local/ca.crt";
            changeMode = "restart";
            data = ''
              {{ with secret "secret/data/nomad/infra/root_ca" }}{{ .Data.data.value }}{{ end }}
            '';
          }
          {
            destination = "local/config.json";
            changeMode = "restart";
            leftDelimiter = "[[";
            rightDelimiter = "]]";
            data =
              let
                json = {
                  image = {
                    colorspace = "p3";
                    extractEmbedded = false;
                    preview.format = "jpeg";
                    preview.size = 1440;
                    #                                thumbnail.thumbnailFormat = "webp";
                    thumbnail.size = 250;
                    thumbnail.quality = 80;
                  };
                  job = {
                    backgroundTask.concurrency = 5;
                    faceDetection.concurrency = 2;
                    library.concurrency = 5;
                    metadataExtraction.concurrency = 5;
                    migration.concurrency = 5;
                    notifications.concurrency = 5;
                    search.concurrency = 5;
                    sidecar.concurrency = 5;
                    smartSearch.concurrency = 2;
                    thumbnailGeneration.concurrency = 5;
                    videoConversion.concurrency = 1;
                  };
                  library = {
                    scan = { cronExpression = "0 0 * * *"; enabled = true; };
                    watch.enabled = false;
                  };
                  logging = { enabled = true; level = "log"; };
                  machineLearning = {
                    urls = [ "http://${lib.localhost}:${toString ports.ml-http}" ];
                    #                                classification = { enabled = true; minScore = 0.7; modelName = "microsoft/resnet-50"; };
                    clip = { enabled = true; modelName = "ViT-B-32::openai"; };
                    duplicateDetection = { enabled = true; maxDistance = 0.01; };
                    enabled = true;
                    facialRecognition = {
                      enabled = true;
                      maxDistance = 0.6;
                      minFaces = 1;
                      minScore = 0.7;
                      modelName = "buffalo_l";
                    };
                  };
                  newVersionCheck.enabled = true;
                  passwordLogin.enabled = true;
                  reverseGeocoding.enabled = true;
                  server = {
                    externalDomain = "https://immich.dcotta.com";
                    loginPageMessage = "";
                  };
                  storageTemplate = {
                    enabled = false;
                    hashVerificationEnabled = true;
                    template = "{{y}}-{{MM}}/{{filename}}";
                  };
                  #                              thumbnail = {
                  #                                colorspace = "p3";
                  #                                jpegSize = 1440;
                  #                                quality = 90;
                  #                                webpSize = 250;
                  #                              };
                  trash = { days = 30; enabled = true; };
                  user.deleteDelay = 7;
                  oauth = {
                    autoRegister = true;
                    buttonText = "Login with Vault";
                    clientId = ''[[ .Data.data.client_id ]]'';
                    clientSecret = ''[[ .Data.data.client_secret ]]'';
                    issuerUrl = ''[[ .Data.data.issuer_url ]]'';
                    defaultStorageQuota = 0;
                    enabled = true;
                    mobileOverrideEnabled = false;
                    #                      mobileRedirectUri = "";
                    scope = "openid email";
                    signingAlgorithm = "RS256";
                    #              storageLabelClaim = "preferred_username";
                    #              storageQuotaClaim = "immich_quota";
                  };
                };
              in
              ''[[ with secret "secret/data/nomad/job/immich/vault_oidc" ]]
           ${builtins.toJSON json }
           [[end]]''
            ;
          }
        ];
      };
    };

    group."immich-ml" = {
      inherit restart;
      count = 1;
      network = {
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };
      ephemeralDisk = {
        size = 5000; # MB
        migrate = true;
        sticky = true;
      };
      service."immich-ml-http" = {
        connect.sidecarService = {
          proxy = {
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-immich-ml-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.ml-http;
      };

      task."immich-ml" = {
        driver = "docker";
        vault = { };

        config = {
          image = "ghcr.io/immich-app/immich-machine-learning:${version}";
          #     TODO?   args = [];
        };
        env = {
          IMMICH_PORT = toString ports.ml-http;
          OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:${toString otlpPort}";
          #        OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:${toString otlpPort}";
          OTEL_TRACES_EXPORTER = "otlp";
          OTEL_SERVICE_NAME = "immich-ml";
          OTEL_SDK_DISABLED = "false";
          NODE_OPTIONS = "--require @opentelemetry/auto-instrumentations-node/register";
        };
        resources = resources-ml;
      };
    };

    group."immich-dbs" = {
      inherit restart;

      constraints = [{
        attribute = "\${meta.box}";
        operator = "=";
        value = "hez1";
      }];

      volume."immich-db" = {
        name = "immich-db";
        type = "host";
        readOnly = false;
        source = "immich-db";
      };

      network = {
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };
      service."immich-redis" = {
        port = toString ports.redis;
        connect.sidecarService.proxy = {
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-immich-redis";
            otlpUpstreamPort = otlpPort;
            protocol = "tcp";
          };
        };
      };
      service."immich-postgres" = {
        port = toString ports.postgres;
        connect.sidecarService.proxy = {
          upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-immich-postgres";
            otlpUpstreamPort = otlpPort;
            protocol = "tcp";
          };
        };
      };
      task."redis" = {
        driver = "docker";
        config.image = "redis:7.2";
        env = {
          REDIS_PASSWORD = "immich";
          REDIS_USERNAME = "immich";
          REDIS_PORT = toString ports.redis;
        };
      };
      task."postgres" = {
        driver = "docker";

        config = {
          image = "tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0";
          command = "postgres";
          args = [
            "-c"
            "shared_preload_libraries=vectors.so"
            "-c"
            "search_path=\"$user\", public, vectors"
            "-c"
            "logging_collector=on"
            "-c"
            "max_wal_size=2GB"
            "-c"
            "shared_buffers=512MB"
            "-c"
            "wal_compression=on"
          ];
          ports = [ "postgres" ];
        };
        env = {
          "POSTGRES_USER" = "immich";
          "POSTGRES_DB" = "immich";
        };
        templates = [{
          destination = "config/.env";
          env = true;
          changeMode = "restart";
          data = ''{{ with nomadVar "nomad/jobs/immich" }}POSTGRES_PASSWORD={{ .db_password }}{{ end }}'';
        }];
        volumeMounts = [{
          volume = "immich-db";
          destination = "/var/lib/postgresql/data";
          readOnly = false;
        }];
        inherit resources;
      };
    };
  };
}
