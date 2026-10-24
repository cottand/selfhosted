{ util, time, defaults, ... }:
let
  name = "mqttui";
  version = "v2.0.2";
  cpu = 100;
  mem = 128;
  ports = {
    http = 5000;
    mqtt = 1883;
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 {
    inherit cpu;
    memory = mem;
    memoryMax = mem * 2;
  };
  otlpPort = 9001;
in
{
  job."${name}" = {
    group."${name}" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      service."${name}" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "mosquitto-mqtt"; localBindPort = ports.mqtt; }
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "${name}-health";
          port = "health";
          type = "http";
          path = "/version";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}.entrypoints=web, websecure"
          "traefik.http.routers.${name}.tls=true"
        ];
      };

      task."${name}" = {
        driver = "docker";
        vault = { };
        config.image = "terdia07/mqttui:${version}";

        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = mem * 2;
        };

        env = {
          PORT = toString ports.http;
          MQTT_BROKER = "127.0.0.1";
          MQTT_PORT = toString ports.mqtt;
          DB_ENABLED = "false";
          MQTTUI_ADMIN_USER = "admin";
        };

        templates = [{
          destination = "secrets/env";
          changeMode = "restart";
          env = true;
          data = ''
            {{ with secret "secret/data/nomad/job/mqttui/auth" }}
            MQTTUI_ADMIN_PASSWORD={{ .Data.data.adminPassword }}
            SECRET_KEY={{ .Data.data.secretKey }}
            {{ end }}
          '';
        }];
      };
    };
  };
}
