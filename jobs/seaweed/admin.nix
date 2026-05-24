 {util, ...}:
  let version = "4.03";
  cpu = 100;
  mem = 200;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  in
  {
    job."seaweed-master".group."seaweed-admin" = {
      count = 2;
      network = {
        mode = "bridge";
      };

      service."seaweed-admin" = {
        port = "9334";
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "seaweed-master-http"; localBindPort = 9333; }
              { destinationName = "seaweed-master-grpc"; localBindPort = 19333; }
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

      task."seaweed-admin" = {
        driver = "docker";
        config = {
          image = "chrislusf/seaweedfs:${version}";
          args = [
            "-logtostderr"
            "admin"
            "-master=localhost:9333"
            "-port=9334"
          ];
        };
        resources = {
          cpu = 50;
          memory = 64;
          memoryMax = 128;
        };
      };
    };
}