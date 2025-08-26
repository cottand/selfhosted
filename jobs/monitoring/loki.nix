{ util, time, defaults, ... }:
let
  lib = (import ../lib) {};
  version = "3.5.1";
  cpu = 200;
  mem = 1024;
  ports = {
    http = 8080;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
in
{
  job."loki" = {
    group."loki" = {
      affinities = [{
        attribute = "\${meta.controlPlane}";
        operator = "=";
        value = "true";
        weight = -50;
      }];
      count = 1;
      network = {
        mode = "bridge";
        port."health" = {
          hostNetwork = "ts";
        };
      };
      volume."docker-sock" = {
        type = "host";
        source = "docker-sock-ro";
        readOnly = true;
      };
      ephemeralDisk = {
        size = 500;
        sticky = true;
        migrate = true;
      };

      service."loki-http" = {
        port = toString ports.http;
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];

            config = lib.mkEnvoyProxyConfig {
              otlpUpstreamPort = otlpPort;
              otlpService = "proxy-loki";
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
      # TODO implement http healthcheck at /ready
      #      port = toString ports.http;
      #      check = {
      #        name = "alive";
      #        type = "tcp";
      #        port = "http";
      #        interval = "20s";
      #        timeout = "2s";
      #      };a
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        ];
      };
        task."loki" = {
        driver = "docker";
        vault = { };
        user = "root:root";

        config = {
          image = "grafana/loki:${version}";
          args = [
            "-config.file=/local/loki.yaml"
#          "--pattern-ingester.enabled=true"
          ];
        };
        volumeMounts = [{
          volume = "docker-sock";
          destination = "/var/run/docker.sock";
          readOnly = true;
        }];
        # loki won't start unless the sinks(backends) configured are healthy
        env = {
          loki_CONFIG = "/local/loki.yaml";
          loki_REQUIRE_HEALTHY = "true";
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);
        };
        templates = [{
          destination = "local/loki.yaml";
          changeMode = "restart";
          leftDelimiter = "[[";
          rightDelimiter = "]]";
          # language=toml
          data = /* language=toml */ ''
          auth_enabled: false
          server:
            http_listen_port: ${toString ports.http}
            http_listen_address: ${bind}

          ingester:
            wal:
              dir: /alloc/data/wal

          common:
            ring:
              instance_addr: 127.0.0.1
              kvstore:
                store: inmemory
            replication_factor: 1
            path_prefix: /alloc/data/loki

          schema_config:
            configs:
            - from: 2020-05-15
              store: tsdb
              object_store: filesystem
              schema: v13
              index:
                prefix: index_
                period: 24h

          storage_config:
            filesystem:
              directory: /alloc/data/loki/chunks

          compactor:
            working_directory: /alloca/data/loki/retention

            compaction_interval: 10m
            retention_delete_delay: 2h
            retention_delete_worker_count: 150
            delete_request_store: filesystem

          '';
        }];
      };
    };
  };
}
