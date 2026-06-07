{ util, time, defaults, ... }:
let
  version = "4.31";
  cpu = 100;
  mem = 200;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  ports.metrics = 12345;
in
{
  job."seaweed-master".group."seaweed-worker" = {
    count = 3;
    network = {
      mode = "bridge";
      port."metrics".hostNetwork = "ts";
        dns.servers = defaults.dns.servers;
    };
    volume."seaweed-worker" = {
      type = "host";
      readOnly = false;
      source = "seaweedfs-worker";
    };

    service."seaweed-worker-metrics" = rec {
      port = toString ports.metrics;
      connect.sidecarService = {
        proxy = {
          upstreams = [
            { destinationName = "seaweed-admin-http"; localBindPort = 9334; }
            { destinationName = "seaweed-admin-grpc"; localBindPort = 19334; }
            { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = 4320; }
          ];
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-worker";
            otlpUpstreamPort = 4320;
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      meta = {
        metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        metrics_path = "/metrics";
      };
      checks = [
        {
          name = "metrics";
          expose = true;
          port = "metrics";
          type = "http";
          path = meta.metrics_path;
          interval = 10 * time.second;
          timeout = 3 * time.second;
        }
#        {
#          name = "health";
##          expose = true;
##          port = "metrics";
#          type = "http";
#          path = "/health";
#          interval = 10 * time.second;
#          timeout = 3 * time.second;
#        }
      ];
    };


    task."seaweed-worker" = {
      driver = "docker";
      config = {
        image = "chrislusf/seaweedfs:${version}";
        args = [
          "-logtostderr"
          "worker"
#                    "-address" ????
          "-metricsPort=${toString ports.metrics}"
          "-metricsIp=127.0.0.1"
          "-workingDir=/seaweed-worker"
          "-admin=hez1.${util.tailscaleDns}:9334"
        ];
      };
      resources = {
        cpu = 50;
        memory = 64;
        memoryMax = 128;
      };
      volumeMounts = [{
        volume = "seaweed-worker";
        destination = "/seaweed-worker";
        readOnly = false;
      }];
    };
  };
}
