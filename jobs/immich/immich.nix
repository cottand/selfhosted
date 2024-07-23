let
  lib = import ../lib;
  version = "v1.109.2";
  domain = "immich.dcotta.com";
  cpu = 220;
  mem = 512;
  ports = {
    http = 8080;
    ml-http = 8081;
    upS3 = 3333;
    redis = 6379;
    postgres = 5432;
    metrics = 9091;
    services-mertrics = 9092;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  mkResrouces = { factor }: with builtins; mapAttrs (_: ceil) {
    cpu = factor * cpu;
    memoryMB = factor * mem;
    memoryMaxMB = factor * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
  kiB = 1024;
  restartConfig = {
    attempts = 4;
    interval = 10 * lib.minutes;
    delay = 20 * lib.seconds;
    mode = "delay";
  };
in
lib.mkJob "immich" {
  affinities = [{
    lTarget = "\${meta.controlPlane}";
    operand = "is";
    rTarget = "true";
    weight = -50;
  }];
  # TODO reenable when healthchecks
  #  update = {
  #    maxParallel = 1;
  #    autoRevert = true;
  #    autoPromote = true;
  #    canary = 1;
  #  };

  group."immich" = {
    inherit restartConfig;
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
        { label = "metrics"; }
        { label = "services-metrics"; }
      ];
      dns.serviers = [ "10.10.11.1" "10.10.12.1" "10.10.13.1" ];
    };
    volumes."immich-pictures" = {
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
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."immich-postgres".localBindPort = ports.postgres;
          upstream."immich-redis".localBindPort = ports.redis;
          upstream."immich-ml-http".localBindPort = ports.ml-http;

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
      check = {
        name = "alive";
        type = "tcp";
        port = "health";
        interval = "20s";
        timeout = "2s";
      };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_TASK_NAME}.entrypoints=web,websecure,web_public,websecure_public"
        "traefik.http.routers.\${NOMAD_TASK_NAME}.rule=Host(`${domain}`) || Host(`immich-http.tfk.nd`)"
        "traefik.http.routers.\${NOMAD_TASK_NAME}.tls=true"
        #        "traefik.http.routers.\${NOMAD_TASK_NAME}.middlewares=ratelimit-immich"
        #        "traefik.http.middlewares.ratelimit-immich.ratelimit.average=120"
        #        "traefik.http.middlewares.ratelimit-immich.ratelimit.period=1m"
      ];
    };
    service."immich-metrics" = {
      connect.sidecarService.proxy.config = lib.mkEnvoyProxyConfig {
        otlpService = "proxy-immich-http";
        otlpUpstreamPort = otlpPort;
        protocol = "http";
      };
      connect.sidecarTask.resources = mkResrouces { factor = 0.15; };
      # TODO implement http healthcheck
      port = toString ports.metrics;
      meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      meta.metrics_path = "/metrics";
      checks = [{
        expose = true;
        name = "metrics";
        portLabel = "metrics";
        type = "http";
        path = "/metrics";
        interval = 30 * lib.seconds;
        timeout = 5 * lib.seconds;
        checkRestart = {
          limit = 3;
          grace = 70 * lib.seconds;
          ignore_warnings = false;
        };
      }];
    };
    service."immich-services-metrics" = {
      connect.sidecarService.proxy.config = lib.mkEnvoyProxyConfig {
        otlpService = "proxy-immich-http";
        otlpUpstreamPort = otlpPort;
        protocol = "http";
      };
      connect.sidecarTask.resources = mkResrouces { factor = 0.15; };
      # TODO implement http healthcheck
      port = toString ports.services-mertrics;
      meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      meta.metrics_path = "/metrics";
      checks = [{
        expose = true;
        name = "services-metrics";
        portLabel = "services-metrics";
        type = "http";
        path = "/metrics";
        interval = 30 * lib.seconds;
        timeout = 5 * lib.seconds;
        checkRestart = {
          limit = 3;
          grace = 70 * lib.seconds;
          ignore_warnings = false;
        };
      }];
    };
    task."immich" = {
      driver = "docker";
      vault = { };

      config = {
        image = "ghcr.io/immich-app/immich-server:${version}";
        #     TODO?   args = [];
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
        IMMICH_METRICS = "true";
        IMMICH_API_METRICS_PORT = toString ports.metrics;
        IMMICH_MICROSERVICES_METRICS_PORT = toString ports.services-mertrics;
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      volumeMounts = [{
        volume = "immich-pictures";
        destination = "/vol/immich-pictures";
        readOnly = false;
      }];
      template."config/.env" = {
        changeMode = "restart";
        envvars = true;
        embeddedTmpl = ''
          {{ with nomadVar "nomad/jobs/immich" }}
          TYPESENSE_API_KEY="{{ .typesense_api_key }}"
          DB_PASSWORD="{{ .db_password }}"
          DB_USERNAME={{ .db_user }}
          {{ end -}}

          IMMICH_SERVER_URL=http://{{ env "NOMAD_IP_server" }}:{{ env "NOMAD_HOST_PORT_server" }}

          ENABLE_TYPESENSE="false"
        '';
      };
      template."local/config.json" = {
        changeMode = "restart";
        leftDelim = "[[";
        rightDelim = "]]";
        embeddedTmpl = builtins.toJSON
          {
            image = {
              colorspace = "p3";
              extractEmbedded = false;
              previewFormat = "jpeg";
              previewSize = 1440;
              quality = 80;
              thumbnailFormat = "webp";
              thumbnailSize = 250;
            };
            job = {
              backgroundTask.concurrency = 5;
              faceDetection.concurrency = 2;
              library.concurrency = 5;
              metadataExtraction.concurrency = 5;
              migration.concurrency = 5;
              notifications.concurrency = 5;
              objectTagging.concurrency = 2;
              recognizeFaces.concurrency = 2;
              search.concurrency = 5;
              sidecar.concurrency = 5;
              smartSearch.concurrency = 2;
              storageTemplateMigration.concurrency = 5;
              thumbnailGeneration.concurrency = 5;
              videoConversion.concurrency = 1;
            };
            library = {
              scan = { cronExpression = "0 0 * * *"; enabled = true; };
              watch.enabled = false;
            };
            logging = { enabled = true; level = "log"; };
            machineLearning = {
              url = "http://127.0.0.1:${toString ports.ml-http}";
              classification = { enabled = true; minScore = 0.7; modelName = "microsoft/resnet-50"; };
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
            server = { externalDomain = "immich.dcotta.com"; loginPageMessage = ""; };
            storageTemplate = {
              enabled = false;
              hashVerificationEnabled = true;
              template = "{{y}}-{{MM}}/{{filename}}";
            };
            thumbnail = {
              colorspace = "p3";
              jpegSize = 1440;
              quality = 90;
              webpSize = 250;
            };
            trash = { days = 30; enabled = true; };
            user = { deleteDelay = 7; };
          };
      };
    };
  };

  group."immich-ml" = {
    inherit restartConfig;
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
      ];
      dns.serviers = [ "10.10.11.1" "10.10.12.1" "10.10.13.1" ];
    };
    ephemerealDisk = {
      size = 5000; # MB
      migrate = true;
      sticky = true;
    };
    service."immich-ml-http" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-immich-ml-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      # TODO implement http healthcheck
      port = toString ports.ml-http;
    };

    task."immich-ml" = {
      driver = "docker";
      vault = { };

      config = {
        image = "ghcr.io/immich-app/immich-machine-learning:${version}";
        #     TODO?   args = [];
      };
      env.IMMICH_PORT = toString ports.ml-http;
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
    };
  };

  group."immich-dbs" = {
    inherit restartConfig;

    constraints = [{
      lTarget = "\${meta.box}";
      operand = "=";
      rTarget = "hez1";
    }];

    volumes."immich-db" = {
      name = "immich-db";
      type = "host";
      readOnly = false;
      source = "immich-db";
    };

    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
      ];
      dns.serviers = [ "10.10.11.1" "10.10.12.1" "10.10.13.1" ];
    };
    service."immich-redis" = {
      port = toString ports.redis;
      check = {
        name = "alive";
        type = "tcp";
        port = "health";
        interval = "20s";
        timeout = "2s";
      };
      connect.sidecarService.proxy = {
        config = lib.mkEnvoyProxyConfig {
          otlpService = "proxy-immich-redis";
          otlpUpstreamPort = otlpPort;
          protocol = "tcp";
        };
      };
    };
    service."immich-postgres" = {
      port = toString ports.postgres;
      check = {
        name = "alive";
        type = "tcp";
        port = "health";
        interval = "20s";
        timeout = "2s";
      };
      connect.sidecarService.proxy = {
        upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
        config = lib.mkEnvoyProxyConfig {
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
        args = [ "-c" "shared_preload_libraries=vectors.so" "-c" "search_path=\"$user\", public, vectors" "-c" "logging_collector=on" "-c" "max_wal_size=2GB" "-c" "shared_buffers=512MB" "-c" "wal_compression=on" ];
        ports = [ "postgres" ];
      };
      env = {
        "POSTGRES_USER" = "immich";
        "POSTGRES_DB" = "immich";
      };
      template."config/.env" = {
        envvars = true;
        changeMode = "restart";
        embeddedTmpl = ''{{ with nomadVar "nomad/jobs/immich" }}POSTGRES_PASSWORD={{ .db_password }}{{ end }}'';
      };
      volumeMounts = [{
        volume = "immich-db";
        destination = "/var/lib/postgresql/data";
        readOnly = false;
      }];
      resources = {
        cpu = 256;
        memoryMb = 250;
        memoryMaxMb = 950;
      };
    };
  };
}
