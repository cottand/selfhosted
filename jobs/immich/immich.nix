let
  lib = import ../lib;
  version = "v1.108.0";
  domain = "immich-http.tfk.nd";
  cpu = 220;
  mem = 512;
  ports = {
    http = 8080;
    ml-http = 8081;
    upS3 = 3333;
    redis = 6379;
    postgres = 5432;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
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
  update = {
    maxParallel = 1;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
  };

  group."immich" = {
    inherit restartConfig;
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
      ];
      dns.serviers = [ "10.10.11.1" "10.10.12.1" "10.10.13.1" ];
    };
    volumes."immich-pictures" = {
      name = "immich-pictures";
      type = "csi";
      readOnly = false;
      source = "immich-pictures";
      accessMode     = "single-node-writer";
      attachmentMode = "file-system";
    };
    service."immich-http" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."immich-postgres".localBindPort = ports.postgres;
          upstream."immich-redis".localBindPort = ports.redis;
          upstream."immich-ml".localBindPort = ports.ml-http;

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
        "traefik.http.routers.\${NOMAD_TASK_NAME}.entrypoints=web, websecure"
        "traefik.http.routers.\${NOMAD_TASK_NAME}.rule=Host(`${domain}`)"
        "traefik.http.routers.\${NOMAD_TASK_NAME}.tls=true"
        "traefik.http.routers.\${NOMAD_TASK_NAME}.middlewares=vpn-whitelist@file"
      ];
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
        envvars  = true;
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
            ffmpeg = {
              accel = "disabled";
              crf = 23;
              maxBitrate = "0";
              preset = "ultrafast";
              targetAudioCodec = "aac";
              targetResolution = "720";
              targetVideoCodec = "h264";
              threads = 0;
              tonemap = "hable";
              transcode = "required";
              twoPass = false;
            };
            job = {
              backgroundTask.concurrency = 5;
              metadataExtraction.concurrency = 5;
              objectTagging.concurrency = 2;
              recognizeFaces.concurrency = 2;
              search.concurrency = 5;
              sidecar.concurrency = 5;
              storageTemplateMigration.concurrency = 5;
              thumbnailGeneration.concurrency = 5;
              videoConversion.concurrency = 1;
            };
            machineLearning = {
              enabled = true;
              classification = {
                enabled = true;
                minScore = 0.7;
                modelName = "microsoft/resnet-50";
              };
              clip = { enabled = true; modelName = "ViT-B-32::openai"; };
              facialRecognition = { enabled = true; maxDistance = 0.6; minFaces = 1; minScore = 0.7; modelName = "buffalo_l"; };
              url = "http://${bind}:${toString ports.ml-http}";
            };
            oauth = {
              autoLaunch = false;
              autoRegister = true;
              buttonText = "Login with OAuth";
              clientId = "";
              clientSecret = "";
              enabled = false;
              issuerUrl = "";
              mobileOverrideEnabled = false;
              mobileRedirectUri = "";
              scope = "openid email profile";
              storageLabelClaim = "preferred_username";
            };
            server.externalDomain = domain;
            passwordLogin.enabled = true;
            storageTemplate.template = "{{y}}-{{MM}}/{{filename}}";
            thumbnail = { colorspace = "p3"; jpegSize = 1440; quality = 90; webpSize = 250; };
          }
        ;
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
      check = {
        name = "alive";
        type = "tcp";
        port = "health";
        interval = "20s";
        timeout = "2s";
      };
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
