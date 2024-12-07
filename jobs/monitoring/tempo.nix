let
  lib = (import ../lib) { };
  version = "2.6.1";
  cpu = 256;
  mem = 700;
  ports = {
    http = 8080;
    otlp-grpc = 12348;
    grpc = 8092;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
in
lib.mkJob "tempo" {
  group."tempo" = {
    ephemeralDisk = {
      migrate = true;
      sizeMb = 5000;
      sticky = true;
    };
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; hostNetwork = "ts"; }
        { label = "ready"; hostNetwork = "ts"; }
      ];
    };
    service."tempo-metrics" = {
      port = toString ports.http;
      connect.sidecarService = {
        proxy = { };
      };


      connect.sidecarTask.resources = sidecarResources;
      checks = [
        {
          expose = true;
          name = "tempo healthcheck";
          portLabel = "metrics";
          type = "http";
          path = "/metrics";
          interval = 30 * lib.seconds;
          timeout = 10 * lib.seconds;
          checkRestart = {
            limit = 3;
            grace = 120 * lib.seconds;
            ignoreWarnings = false;
          };
        }
        # TODO implement http healthcheck at /ready
        #        {
        #          expose = true;
        #          name = "ready";
        #          portLabel = "ready";
        #          type = "http";
        #          path = "/ready";
        #          interval = 30 * lib.seconds;
        #          timeout = 10 * lib.seconds;
        #          checkRestart = {
        #            limit = 3;
        #            grace = 120 * lib.seconds;
        #            ignoreWarnings = false;
        #          };
        #        }
      ];
      meta.metrics_port = "\${NOMAD_PORT_metrics}";
    };
    service."tempo-http" = {
      port = toString ports.http;
      tags = [
        "traefik.consulcatalog.connect=true"
        "traefik.enable=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
      ];
      connect.sidecarService.proxy = {
        upstream."mimir-http".localBindPort = 8001;
      };
    };
    service."tempo-otlp-grpc-mesh" = {
      port = toString ports.otlp-grpc;
      connect.sidecarService.proxy = { };
    };
    task."tempo" = {
      driver = "docker";
      #      vault = { };
      user = "root:root";

      config = {
        image = "grafana/tempo:${version}";
        args = [ "-config.file" "/local/tempo/local-config.yaml" ];
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      template."local/tempo/local-config.yaml" = {
        changeMode = "restart";
        embeddedTmpl = ''
          auth_enabled: false
          server:
            http_listen_port: ${toString ports.http}
            grpc_listen_port: ${toString ports.grpc}

          distributor:
            # each of these has their separate config - see https://grafana.com/docs/tempo/latest/configuration/#distributor
            receivers:
              # see https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/jaegerreceiver
              jaeger:
                protocols:
              otlp:
                protocols:
                    grpc:
                      endpoint: 0.0.0.0:${toString ports.otlp-grpc}

          #ingester:
            #max_block_duration: 5m               # cut the headblock when this much time passes. this is being set for demo purposes and should probably be left alone normally

          compactor:
            compaction:
              block_retention: 12h                # overall Tempo trace retention.

          metrics_generator:
            registry:
              external_labels:
                source: tempo
                cluster: nomad
            storage:
              path: /alloc/data/tempo/generator/wal
              remote_write:
                - url: http://localhost:8001/api/v1/push
                  send_exemplars: true

          storage:
            trace:
              backend: local                     # backend configuration to use
              wal:
                path: /alloc/data/tempo/wal             # where to store the the wal locally
              local:
                path: /alloc/data/tempo/blocks

          overrides:
            metrics_generator_processors: [service-graphs, span-metrics] # enables metrics generator
        '';
      };
    };
  };
}
