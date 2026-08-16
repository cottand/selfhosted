{ util, time, defaults, ... }:
let
  lib = (import ../lib) { };
  version = "2.12.0";
  cpu = 256;
  mem = 1024;
  ports = {
    http = 5001;
    grpc = 5002;
    memberlist = 7946;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
{
  job."mimir" = {
    update = {
      maxParallel = 1;
      healthCheck = "checks";
      minHealthyTime = 10 * time.second;
      healthyDeadline = 3 * time.minute;
      progressDeadline = 5 * time.minute;
    };
    group."mimir" = {
      count = 1;
      affinities = [{
        attribute = "\${meta.controlPlane}";
        operator = "=";
        value = "true";
        weight = -50;
      }];
      restart = {
        attempts = 3;
        interval = 5 * time.minute;
        delay = 25 * time.second;
        mode = "delay";
      };
      ephemeralDisk = {
        size = 1024;
        migrate = true;
        sticky = true;
      };
      network = {
        mode = "bridge";
        port."healthz" = {
          hostNetwork = "ts";
        };
        port."metrics" = {
          hostNetwork = "ts";
        };
        port."memberlist" = {
          hostNetwork = "ts";
          to = ports.memberlist;
        };
        port."grpc" = {
          hostNetwork = "ts";
        };
      };
      service."mimir-http" = {
        port = toString ports.http;
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        checks = [
          {
            name = "healthz";
            expose = true;
            port = "healthz";
            type = "http";
            path = "/ready";
            interval = 20 * time.second;
            timeout = 5 * time.second;
            checkRestart = {
              limit = 6;
              grace = 120 * time.second;
              ignoreWarnings = false;
            };
          }
          {
            name = "metrics";
            expose = true;
            port = "metrics";
            type = "http";
            path = "/metrics";
            interval = 20 * time.second;
            timeout = 5 * time.second;
            checkRestart = {
              limit = 6;
              grace = 120 * time.second;
              ignoreWarnings = false;
            };
          }
        ];
        meta = {
          metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        };
        tags = [
          "traefik.enable=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        ];
      };
      service."mimir-memberlist" = {
        port = toString ports.memberlist;
      };
      task."mimir" = {
        driver = "docker";
        killTimeout = 5 * time.minute;
        config = {
          image = "grafana/mimir:${version}";
          args = [
            "-config.file"
            "/local/config.yaml"
            "-target=all,alertmanager"
            "-auth.multitenancy-enabled=false"
            "-server.grpc.keepalive.min-time-between-pings=10s"
          ];
          ports = [ "http" "memberlist" ];
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = mem;
        };
        templates = [{
          destination = "local/config.yaml";
          changeMode = "restart";
          leftDelimiter = "[[";
          rightDelimiter = "]]";
          data = ''
            server:
              http_listen_port: ${toString ports.http}
              grpc_listen_port: ${toString ports.grpc}
            common:
              storage:
                backend: s3
                s3:
                  send_content_md5: true
                  bucket_name: mimir-long-term
                  endpoint: s3.us-east-005.backblazeb2.com
                  region: us-east-005
                  [[ with nomadVar "secret/buckets/backblaze-all" ]]
                  secret_access_key: [[ .secretAccessKey ]]
                  access_key_id: [[ .keyId ]]
                  [[ end ]]

            blocks_storage:
              storage_prefix: blocks
              tsdb:
                flush_blocks_on_shutdown: true
                dir: /alloc/data/ingester
              bucket_store:
                sync_dir: /alloc/data/tsdb-sync

            ingester:
              ring:
                replication_factor: 1

            store_gateway:
              sharding_ring:
                replication_factor: 1

            limits:
              compactor_blocks_retention_period: 30d
              native_histograms_ingestion_enabled: true

            querier:
              max_concurrent: 10
          '';
        }];
      };
    };
  };
}
