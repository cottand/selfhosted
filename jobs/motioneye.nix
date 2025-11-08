{ util, time, ... }:
let
  name = "motioneye";
  image = "ghcr.io/motioneye-project/motioneye";
  version = "edge";
  cpu = 1800;
  mem = 400;
  ports = {
    http = 8765;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
{
  job."${name}" = {
    group."${name}" = {
      count = 1;
      network = {
        mode = "bridge";
        port."metrics".hostNetwork = "ts";
      };
      volume."motioneye" = {
        name = "motioneye";
        type = "host";
        readOnly = false;
        source = "motioneye";
      };

      service."${name}" = rec  {
        connect.sidecarService = {
          proxy = {
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.http;
        #        meta = {
        #          metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        #          metrics_path = "/metrics";
        #        };
        checks = [
          #          {
          #            expose = true;
          #            name = "metrics";
          #            port = "metrics";
          #            type = "http";
          #            path = meta.metrics_path;
          #            interval = 10 * time.second;
          #            timeout = 3 * time.second;
          #          }
        ];
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

        volumeMounts = [
          {
            volume = "motioneye";
            destination = "/etc/motioneye";
            readOnly = false;
          }
        ];

        config = {
          image = "${image}:${version}";
          privileged = true;
          mounts = [
            {
              type = "bind";
              source = "/dev/video0";
              target = "/dev/video0";
              readonly = false;
            }
            {
              type = "bind";
              source = "/dev/video1";
              target = "/dev/video1";
              readonly = false;
            }
          ];
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);

          # Webcam C270 (Logitech, Inc.)
          device."046d/usb/0825" = { };
          #          templates = [{
          #            destination = "local/config.conf";
          #            changeMode = "restart";
          #            data = ''
          #              [database]
          #              listen=localhost
          #              port=${ports.http}
          #
          #            '';
          #          }];
        };
      };
    };
  };
}
