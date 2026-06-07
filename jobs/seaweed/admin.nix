{ util, ... }:
let
  version = "4.31";
  cpu = 100;
  mem = 200;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  ports = {
    http = 9334;
    grpc = 19334;
  };
in
{
  job."seaweed-master".group."seaweed-admin" = {
    count = 1;
    network = {
      mode = "bridge";
      reservedPorts = {
        "http" = { static = ports.http; hostNetwork = "ts"; };
        "grpc" = { static = ports.grpc; hostNetwork = "ts"; };
      };
    };
    volume."seaweed-admin" = {
      type = "host";
      readOnly = false;
      source = "seaweedfs-admin";
    };

    service."seaweed-admin-http" = {
      port = toString ports.http;
      connect.sidecarService = {
        proxy = {
          upstreams = [
            { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = 4320; }
          ];
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-admin";
            otlpUpstreamPort = 4320;
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-admin.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-admin.tls=true"
        "traefik.http.routers.seaweed-admin.middlewares=mesh-whitelist@file"
      ];
    };
    service."seaweed-admin-grpc" = {
      port = toString ports.grpc;
      connect.sidecarService = {
        proxy = {
          upstreams = [
          ];
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-admin-grpc";
            otlpUpstreamPort = 4320;
            protocol = "grpc";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      tags = [
        "traefik.enable=false"
      ];
    };

    task."seaweed-admin" = {
      driver = "docker";
      config = {
        image = "chrislusf/seaweedfs:${version}";
        args = [
          "-logtostderr"
          "admin"
          "-master=hez1:9333,hez2:9333,hez3:9333"
          "-port=${toString ports.http}"
          "-port.grpc=${toString ports.grpc}"
          "-dataDir=/seaweed-admin"
        ];
      };
      resources = {
        cpu = 50;
        memory = 64;
        memoryMax = 128;
      };
      volumeMounts = [{
        volume = "seaweed-admin";
        destination = "/seaweed-admin";
        readOnly = false;
      }];
    };
  };
}
