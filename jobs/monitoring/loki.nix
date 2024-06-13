let
  lib = import ../lib;
  version = "2.8.0";
  cpu = 256;
  mem = 512;
  ports = {
    http = 8080;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
in
lib.mkJob "loki" {

  group."loki" = {
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "health"; }
      ];
    };
    volumes."docker-sock" = {
      type = "host";
      source = "docker-sock-ro";
      readOnly = true;
    };
    ephemeralDisk = {
      size = 500;
      sticky = true;
    };

    service."loki" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          #          upstream."seaweed-filer-s3".localBindPort = ports.upS3;

          config = lib.mkEnvoyProxyConfig {
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      # TODO implement http healthcheck
      #      port = toString ports.http;
      #      check = {
      #        name = "alive";
      #        type = "tcp";
      #        port = "http";
      #        interval = "20s";
      #        timeout = "2s";
      #      };
    };
    task."loki" = {
      driver = "docker";
      vault = { };

      config = {
        image = "grafana/loki:${version}";
      };
      volumeMounts = [{
        volume = "docker-sock";
        destination = "/var/run/docker.sock";
        readOnly = true;
      }];
      # loki won't start unless the sinks(backends) configured are healthy
      env = {
        loki_CONFIG = "/local/loki.toml";
        loki_REQUIRE_HEALTHY = "true";
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      template."local/loki.toml" = {
        changeMode = "restart";
        leftDelim = "[[";
        rightDelim = "]]";
        # language=toml
        embeddedTmpl = /* language=toml */ ''
          auth_enabled: false
          server:
            http_listen_port: {{ env "NOMAD_PORT_http" }}
          ingester:
            wal:
              dir: /alloc/data/wal
            lifecycler:
              # not sure it is needed but was in original guide
              #address: 127.0.0.1
              ring:
                kvstore:
                  store: inmemory
                replication_factor: 1
              final_sleep: 0s
            # Any chunk not receiving new logs in this time will be flushed
            chunk_idle_period: 1h
            # All chunks will be flushed when they hit this age, default is 1h
            max_chunk_age: 1h
            # Loki will attempt to build chunks up to 1.5MB, flushing if chunk_idle_period or max_chunk_age is reached first
            chunk_target_size: 1048576
            # Must be greater than index read cache TTL if using an index cache (Default index read cache TTL is 5m)
            chunk_retain_period: 30s
            max_transfer_retries: 0     # Chunk transfers disabled
          schema_config:
            configs:
              - from: 2023-04-20
                store: boltdb-shipper
                object_store: filesystem
                schema: v11
                index:
                  prefix: index_
                  period: 24h
          storage_config:
            boltdb_shipper:
              active_index_directory: /alloc/data/boltdb-shipper-active
              cache_location: /alloca/data/boltdb-shipper-cache
              cache_ttl: 24h         # Can be increased for faster performance over longer query periods, uses more disk space
              shared_store: filesystem
            filesystem:
              directory: /alloc/data/chunks
          compactor:
            working_directory: /tmp/loki/boltdb-shipper-compactor
            shared_store: filesystem
          limits_config:
            reject_old_samples: true
            reject_old_samples_max_age: 168h
          chunk_store_config:
            max_look_back_period: 0s
          table_manager:
            retention_deletes_enabled: false
            retention_period: 0s
          # https://community.grafana.com/t/loki-error-on-port-9095-error-contacting-scheduler/67263
        '';
      };
    };
  };
}
