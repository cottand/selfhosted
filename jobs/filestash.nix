{ util, time, ... }:
let
  name = "filestash";
  version = "latest";
  cpu = 120;
  mem = 500;
  ports = {
    http = 8334;
    #    upDb = 5432;
    upS3 = 3333;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
{
  job."filestash" = {
    update = {
      maxParallel = 1;
      autoRevert = true;
      autoPromote = true;
      canary = 1;
    };

    group."${name}" = {
      count = 1;
      network = {
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };
      volume."filestash" = {
        name = "filestash";
        type = "csi";
        readOnly = false;
        source = "filestash";
        accessMode = "single-node-writer";
        attachmentMode = "file-system";
      };

      service."${name}" = {
        connect.sidecarService = {
          proxy = {
            upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
            upstream."seaweed-filer-s3".localBindPort = ports.upS3;

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        # TODO implement http healthcheck
        port = toString ports.http;
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}-http.entrypoints=web,websecure"
          "traefik.http.routers.${name}-http.tls=true"
        ];
      };
      task."${name}" = {
        driver = "docker";
        vault = { };

        config = {
          image = "machines/filestash:${version}";
        };
        env = {
          APPLICATION_URL = "${name}.tfk.nd";
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);
        };
        volumeMounts = [{
          volume = "filestash";
          destination = "/app/data";
          readOnly = false;
        }];
      };
    };
  };
}
