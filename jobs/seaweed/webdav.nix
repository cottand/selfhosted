let
  lib = (import ../lib) { };
  version = "3.64";
  cpu = 100;
  mem = 100;
  ports = {
    webdav = 12311;
    filer = 8001;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
lib.mkJob "seaweed-webdav" {
  update = {
    maxParallel = 1;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
  };
  group."seaweed-webdav" = {
    count = 1;
    network.mode = "bridge";
    network.dns = lib.defaults.dns;

    service."seaweed-webdav" = {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          # upstream."seaweed-filer-http".localBindPort = ports.filer;
          upstream."seaweed-filer-grpc".localBindPort = ports.filer + 10000;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-web-portfolio";
            otlpUpstreamPort = otlpPort;
            protocol = "tcp";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      # TODO implement http healthcheck https://github.com/seaweedfs/seaweedfs/pull/4899/files
      port = ports.webdav;
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.middlewares=mesh-whitelist@file"
      ];
    };

    task."seaweed-webdav" = {
      driver = "docker";

      config = {
        image = "chrislusf/seaweedfs:${version}";
        args = [
          "-logtostderr"
          # "-v=3"
          "webdav"
          # "-collection=arman"
          # "-replication=010"
          "-port=${toString ports.webdav}"
          "-filer=localhost:${toString ports.filer}"
          #          "-filer.path=/buckets"
          "-cacheDir=/alloc/data/"
          "-cacheCapacityMB=1024"
        ];
      };

      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = mem + mem;
      };
    };
  };
}
