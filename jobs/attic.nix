{ util, time, ... }:
let
  # before changing this, make sure you run DB migrations
  # Here, you run API and GC modes and neither of those run DB migrations.
  # https://github.com/zhaofengli/attic/blob/47752427561f1c34debb16728a210d378f0ece36/server/src/main.rs#L74
  #
  # You can run the migrations by starting Attic in monolithic mode once, in the new version.
  # You can do that by
  # - stop the job entirely via nomad (otherwise there's a canary rollout)
  # - enabling update mode below
  # - update version
  # - deploy
  # - check DB migrations have run oK (eg, by looking into the attic.seaql_migrations table)
  # - disable update updateMode
  # - deploy again, done!
  #  version = "7a19204df10d606c5070e6bb72615c3461900c05"; # newer
  #version = "717cc95983cdc357bc347d70be20ced21f935843"; # older
  image = "ghcr.io/cottand/selfhosted/attic:0763e91";
  updateMode = true;
  cpu = 120;
  mem = 500;
  ports = {
    http = 8888;
    upDb = 5432;
    upS3 = 3333;
  };
  otlpPort = 9001;
  bind = util.localhost;
  kiB = 1024;
  chunkFactor = 4;

  bucketConfigFiler = ''
    [storage]
    type = "s3"
    # The AWS region
    region = "us-east-1"

    # The name of the bucket
    bucket = "attic"
    #endpoint = "http://localhost:${toString ports.upS3}"
    #endpoint = "https://seaweed-filer-s3.tfk.nd"

    # If unset, the credentials are read from the `AWS_ACCESS_KEY_ID` and
    # `AWS_SECRET_ACCESS_KEY` environment variables.
    [storage.credentials]
      access_key_id = ""
      secret_access_key = ""

  '';

  bucketConfigB2 = ''
    {{ with secret "secret/data/nomad/job/attic/b2" }}
    [storage]
    type = "s3"
    # The AWS region
    region = "{{ .Data.data.region }}"

    # The name of the bucket
    bucket = "{{ .Data.data.bucket }}"
    endpoint = "https://{{ .Data.data.endpoint }}"

    # If unset, the credentials are read from the `AWS_ACCESS_KEY_ID` and
    # `AWS_SECRET_ACCESS_KEY` environment variables.
    [storage.credentials]
      access_key_id = "{{ .Data.data.keyID }}"
      secret_access_key = "{{ .Data.data.applicationKey }}"
    {{ end }}
  '';

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
      port."health".hostNetwork = "ts";
    };

    task."attic-${mode}" = {
      action."collect-garbage" = {
        name = "collect-garbage";
        command = "atticd";
        args = [ "-f" "/local/config.toml" "--mode" "garbage-collector-once" ];
      };
      driver = "docker";
      vault = { };

      config = {
        image = image;
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
        memory = mem;
        memoryMax = builtins.ceil (2 * mem);
      };
      # volume-mounted by default by mkjob
      env."SSL_CERT_FILE" = "/etc/ssl/certs/ca-bundle.crt";

      templates = [
        {
          destination = "local/config.toml";
          changeMode = "restart";
          data = ''
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
            # you need to delete DB tables before messing with this :c
            # otherwise the app will expect chunks that do not exist
            ${bucketConfigB2}

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
            default-retention-period = "3 months"
            #default-retention-period = "1 minute"

            [jwt.signing]
            token-hs256-secret-base64 = "{{with secret "secret/data/nomad/job/attic/jwt_signer"}}{{.Data.data.value}}{{end}}"
          '';
        }
      ];
    };
  };
in
{
  job."attic" = {
    group."attic-api" = mkGroup rec {
      mode = "api-server";
      count = if updateMode then 0 else 2;
      resources = {
        cpu = 150;
        memory = 500;
        memoryMax = 1000;
      };
      service."attic" = {
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-attic-http";
              otlpUpstreamPort = otlpPort;

              # to avoid 504s
              # https://developer.hashicorp.com/consul/docs/reference/proxy/envoy#dynamic-configuration
              extra.local_request_timeout_ms = 5 * 60 * 1000;
              extra.local_idle_timeout_ms = 5 * 60 * 1000;
              extra.protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = util.mkResourcesWithFactor 0.15 resources;
        port = toString ports.http;
        checks = [{
          expose = true;
          name = "healthcheck";
          port = "health";
          type = "http";
          path = "/";
          interval = 30 * time.second;
          timeout = 10 * time.second;
          checkRestart = {
            limit = 3;
            grace = 120 * time.second;
            ignoreWarnings = false;
          };
        }];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
          "traefik.http.routers.\${NOMAD_GROUP_NAME} -http.tls=true"
        ];
      };
    };
    group."attic-db-migrations" = mkGroup rec {
      mode = "db-migrations";
      count = if updateMode then 1 else 0;
      resources = {
        cpu = 60;
        memory = 150;
        memoryMax = 1000;
      };
      service = { };
    };
    group."attic-gc" = mkGroup rec {
      mode = "garbage-collector";
      count = if updateMode then 0 else 1;
      resources = {
        cpu = 60;
        memory = 150;
        memoryMax = 1000;
      };
      service."attic-gc" = {
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
            ];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-attic-gc-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = util.mkResourcesWithFactor 0.15 resources;
        port = toString ports.http;
      };
    };
  };
}

