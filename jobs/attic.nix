let
  lib = (import ./lib) { };
  # before changing this, ame sure you implement running
  # db migrations
  # https://github.com/zhaofengli/attic/blob/47752427561f1c34debb16728a210d378f0ece36/server/src/main.rs#L74
  version = "717cc95983cdc357bc347d70be20ced21f935843";
  cpu = 120;
  mem = 500;
  ports = {
    http = 8888;
    upDb = 5432;
    upS3 = 3333;
  };
  otlpPort = 9001;
  bind = lib.localhost;
  kiB = 1024;
  chunkFactor = 4;

  mkGroup = { mode, count, resources, service }: {
    inherit count service;
    update = {
      maxParallel = 1;
      autoRevert = true;
      autoPromote = true;
      canary = 1;
    };

    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; hostNetwork = "ts"; }
      ];
      reservedPorts = [ ];
    };
    volumes = lib.caCertificates.volume;


    task."attic-${mode}" = {
      actions = [{
        name = "collect-garbage";
        command = "atticd";
        args = [ "-f" "/local/config.toml" "--mode" "garbage-collector-once" ];
      }];
      driver = "docker";
      vault = { };

      config = {
        image = "ghcr.io/zhaofengli/attic:${version}";
        args = [
          "--config"
          "/local/config.toml"
          "--listen"
          "${bind}:${toString ports.http}"
          "--mode=${mode}"
        ];
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      # volume-mounted by default by mkjob
      env."SSL_CERT_FILE" = "/etc/ssl/certs/ca-bundle.crt";

      template."local/config.toml" = {
        changeMode = "restart";
        embeddedTmpl = ''
          listen = "${bind}:${toString ports.http}"

          # Allowed `Host` headers
          #
          # This _must_ be configured for production use. If unconfigured or the
          # list is empty, all `Host` headers are allowed.
          allowed-hosts = []

          # The canonical API endpoint of this server
          #
          # This is the endpoint exposed to clients in `cache-config` responses.
          #
          # This _must_ be configured for production use. If not configured, the
          # API endpoint is synthesized from the client's `Host` header which may
          # be insecure.
          #
          # The API endpoint _must_ end with a slash (e.g., `https://domain.tld/attic/`
          # not `https://domain.tld/attic`).
          api-endpoint = "https://attic.tfk.nd/"

          # If this is enabled, caches are soft-deleted instead of actually
          # removed from the database. Note that soft-deleted caches cannot
          # have their names reused as long as the original database records
          # are there.
          soft-delete-caches = false

          # JWT signing token
          # Set this to the Base64 encoding of some random data
          token-hs256-secret-base64 = "{{with secret "secret/data/nomad/job/attic/jwt_signer"}}{{.Data.data.value}}{{end}}"

          # Database connection
          [database]
          # Connection URL
          #
          # For production use it's recommended to use PostgreSQL.
          # tx is read committed set in DB itself
          url = "postgresql://attic:{{with secret "secret/data/nomad/job/attic/db"}}{{.Data.data.password}}{{end}}@localhost:${toString ports.upDb}/attic?options=-c default_int_size=4"

          # Whether to enable sending on periodic heartbeat queries
          #
          # If enabled, a heartbeat query will be sent every minute
          heartbeat = true

          # File storage configuration
          [storage]
          type = "s3"

          # ## S3 Storage (set type to "s3" and uncomment below)
          # The AWS region
          region = "us-east-1"

          # The name of the bucket
          bucket = "attic"
          #endpoint = "http://localhost:${toString ports.upS3}"
          endpoint = "https://seaweed-filer-s3.tfk.nd"

          # If unset, the credentials are read from the `AWS_ACCESS_KEY_ID` and
          # `AWS_SECRET_ACCESS_KEY` environment variables.
          [storage.credentials]
            access_key_id = ""
            secret_access_key = ""

          # Warning: If you change any of the values here, it will be
          # difficult to reuse existing chunks for newly-uploaded NARs
          # since the cutpoints will be different. As a result, the
          # deduplication ratio will suffer for a while after the change.
          [chunking]
          # The minimum NAR size to trigger chunking
          #
          # If 0, chunking is disabled entirely for newly-uploaded NARs.
          # If 1, all NARs are chunked.
          nar-size-threshold = ${toString (chunkFactor * 128 * kiB)} # chunk files that are this or larger

          # The preferred minimum size of a chunk, in bytes
          min-size = ${toString (chunkFactor * 64 * kiB)}

          # The preferred average size of a chunk, in bytes
          avg-size = ${toString (chunkFactor * 128 * kiB)}            # 64 KiB

          # The preferred maximum size of a chunk, in bytes
          max-size = ${toString (chunkFactor * 1024 * kiB)}           # 256 KiB

          # Compression
          [compression]
          # Compression type
          #
          # Can be "none", "brotli", "zstd", or "xz"
          type = "zstd"

          # Compression level
          #level = 8

          # Garbage collection
          [garbage-collection]
          # The frequency to run garbage collection at
          #
          # If zero, automatic garbage collection is disabled, but
          # it can still be run manually with `atticd --mode garbage-collector-once`.
          interval = "12 hours"
          #interval = "1 minute"

          # Zero (default) means time-based garbage-collection is
          # disabled by default. You can enable it on a per-cache basis.
          default-retention-period = "6 months"
          #default-retention-period = "1 minute"
        '';
      };
      volumeMounts = [ lib.caCertificates.volumeMount ];
    };
  };
in
lib.mkJob "attic" {
  group."attic-api" = mkGroup rec {
    mode = "api-server";
    count = 2;
    resources = {
      cpu = 150;
      memoryMB = 500;
      memoryMaxMB = 1000;
    };
    service."attic" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."roach-db".localBindPort = ports.upDb;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-attic-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = lib.mkResourcesWithFactor 0.15 resources;
      port = toString ports.http;
      checks = [{
        expose = true;
        name = "healthcheck";
        portLabel = "health";
        type = "http";
        path = "/";
        interval = 30 * lib.seconds;
        timeout = 10 * lib.seconds;
        checkRestart = {
          limit = 3;
          grace = 120 * lib.seconds;
          ignoreWarnings = false;
        };
      }];
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls=true"
      ];
    };
  };
  group."attic-gc" = mkGroup rec {
    mode = "garbage-collector";
    count = 1;
    resources = {
      cpu = 60;
      memoryMB = 150;
      memoryMaxMB = 1000;
    };
    service."attic-gc" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."roach-db".localBindPort = ports.upDb;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-attic-gc-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = lib.mkResourcesWithFactor 0.15 resources;
      port = toString ports.http;
    };
  };
}
