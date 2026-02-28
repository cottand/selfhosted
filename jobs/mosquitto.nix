{ util, time, ... }:
let
  name = "mosquitto";
  image = "eclipse-mosquitto";
  version = "2";
  cpu = 200;
  mem = 128;
  port = 1883;
  metricsPort = 9234;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  vaultSecret = "secret/data/nomad/job/mosquitto/auth";
in
{
  job."${name}" = {
    group."${name}" = {
      count = 1;

      constraints = [{
        attribute = "\${meta.box}";
        operator = "=";
        value = "imac";
      }];

      network = {
        mode = "bridge";
        reservedPorts."mqtt" = {
          static = port;
          hostNetwork = "home_lan";
        };
        port."metrics".hostNetwork = "ts";
      };

      service."${name}-mqtt" ={
        connect.sidecarService = {
          proxy = {
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-mqtt";
              otlpUpstreamPort = otlpPort;
              protocol = "tcp";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString port;
        checks = [];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          #"traefik.tcp.routers.${name}-mqtt.tls.passthrough=true"
          "traefik.tcp.routers.${name}-mqtt.rule=HostSNI(`${name}-mqtt.traefik`) || HostSNI(`${name}-mqtt.tfk.nd`)"
          "traefik.tcp.routers.${name}-mqtt.entrypoints=web,websecure"
          "traefik.tcp.routers.${name}-mqtt.tls=true"
        ];
      };
      service."${name}-metrics" = rec {
        connect.sidecarService = {
          proxy = {
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-metrics";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString metricsPort;
        meta = {
          metrics_port = "\${NOMAD_HOST_PORT_metrics}";
          metrics_path = "/metrics";
        };
        checks = [{
          expose = true;
          name = "metrics";
          port = "metrics";
          type = "http";
          path = meta.metrics_path;
          interval = 10 * time.second;
          timeout = 3 * time.second;
        }];
        tags = [
          "traefik.enable=false"
        ];
      };

      task."${name}" = {
        driver = "docker";

        config = {
          image = "${image}:${version}";
          ports = [ "mqtt" ];
        };

        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);
        };

        templates = [{
          destination = "local/mosquitto.conf";
          changeMode = "restart";
          data = ''
            listener ${toString port} 0.0.0.0
            allow_anonymous true
          '';
        }];

        config.mount = [{
          type = "bind";
          source = "local/mosquitto.conf";
          target = "/mosquitto/config/mosquitto.conf";
          readonly = true;
        }];
      };

      task."${name}-exporter" = {
        lifecycle = {
          hook = "poststart";
          sidecar = true;
        };
        driver = "docker";
        vault = { };
        config = {
          image = "sapcc/mosquitto-exporter:latest";
          ports = [ "metrics" ];
        };
        resources = {
          cpu = 50;
          memory = 64;
          memoryMax = 128;
        };
        templates = [{
          destination = "secrets/mqtt.env";
          changeMode = "restart";
          env = true;
          data = ''
            {{ with secret "${vaultSecret}" }}
            MQTT_USER={{ .Data.data.username }}
            MQTT_PASS={{ .Data.data.password }}
            {{ end }}
          '';
        }];
      };
    };
  };
}
