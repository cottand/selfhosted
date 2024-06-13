let
  lib = import ./lib;
  version = "717cc95983cdc357bc347d70be20ced21f935843";
  cpu = 120;
  mem = 500;
  ports = {
    http = 8888;
    upDb = 5432;
    upS3 = 3333;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
  kiB = 1024;
  chunkFactor = 1;
in
lib.mkJob "attic" {

  update = {
    maxParallel = 1;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
  };

  group."attic" = {
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
      ];
      reservedPorts = [
        { label = "http"; value = ports.http; }
      ];
    };

    service."attic" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."roach-db".localBindPort = ports.upDb;
          upstream."seaweed-filer-s3".localBindPort = ports.upS3;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-attic-http";
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
        port = "http";
        interval = "20s";
        timeout = "2s";
      };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.middlewares=mesh-whitelist@file"
      ];
    };
    task."attic" = {
      driver = "docker";
      vault = { };

      config = {
        image = "ghcr.io/zhaofengli/attic:${version}";
        # ports = ["http" "grpc", "metrics", "webdav"];
        args = [
          "--config"
          "/local/config.toml"
          "--listen"
          "${bind}:${toString ports.http}"
        ];
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      template."local/config.toml" = {
        changeMode = "restart";
        embeddedTmpl = ''
          # Socket address to listen on
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
          #soft-delete-caches = false

          # Whether to require fully uploading a NAR if it exists in the global cache.
          #
          # If set to false, simply knowing the NAR hash is enough for
          # an uploader to gain access to an existing NAR in the global
          # cache.
          #require-proof-of-possession = true

          # JWT signing token
          #
          # Set this to the Base64 encoding of some random data.
          # You can also set it via the `ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64` environment
          # variable.
          token-hs256-secret-base64 = "{{with secret "secret/data/nomad/job/attic/jwt_signer"}}{{.Data.data.value}}{{end}}"

          # Database connection
          [database]
          # Connection URL
          #
          # For production use it's recommended to use PostgreSQL.
          url = "postgresql://attic:{{with secret "secret/data/nomad/job/attic/db"}}{{.Data.data.password}}{{end}}@localhost:${toString ports.upDb}/attic?options=-c default_int_size=4"

          # Whether to enable sending on periodic heartbeat queries
          #
          # If enabled, a heartbeat query will be sent every minute
          #heartbeat = true

          # File storage configuration
          [storage]
          # Storage type
          #
          # Can be "local" or "s3".
          type = "s3"

          # ## Local storage
          # The directory to store all files under
          #path = "/local/share/attic/storage"

          # ## S3 Storage (set type to "s3" and uncomment below)
          # The AWS region
          region = "us-east-1"

          # The name of the bucket
          bucket = "attic"

          # Custom S3 endpoint
          #
          # Set this if you are using an S3-compatible object storage (e.g., Minio).
          #endpoint = "http://localhost:${toString ports.upS3}"
          endpoint = "http://10.10.0.1:13210"

          # Credentials
          #
          # If unset, the credentials are read from the `AWS_ACCESS_KEY_ID` and
          # `AWS_SECRET_ACCESS_KEY` environment variables.
          [storage.credentials]
            access_key_id = ""
            secret_access_key = ""

          # Data chunking
          #
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
          # By default it's 12 hours. You can use natural language
          # to specify the interval, like "1 day".
          #
          # If zero, automatic garbage collection is disabled, but
          # it can still be run manually with `atticd --mode garbage-collector-once`.
          interval = "12 hours"

          # Default retention period
          #
          # Zero (default) means time-based garbage-collection is
          # disabled by default. You can enable it on a per-cache basis.
          default-retention-period = "6 months"
        '';
      };
    };
  };
}
