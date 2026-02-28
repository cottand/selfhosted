{ util, time, ... }:
let
  name = "minecraft";
  image = "itzg/minecraft-server";
  version = "latest";
  cpu = 3000;
  mem = 2500;
  port = 25565;
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
        reservedPorts."game" = {
          static = port;
          hostNetwork = "ts";
        };
        port."metrics".hostNetwork = "ts";
      };

      volume."minecraft-data" = {
        name = "minecraft-data";
        type = "host";
        readOnly = false;
        source = "minecraft-data";
      };

      service."${name}" = {
        port = toString port;
        checks = [ ];
        tags = [
          "traefik.enable=false"
        ];
      };

#      task."${name}-metrics" = {
#
#        lifecycle = {
#          hook = "poststart";
#          sidecar = true;
#        };
#        driver = "docker";
#        config = {
#          image = "itzg/mc-monitor:0.16.0";
#          args = [
#            "export-for-prometheus"
#            "-servers=localhost:${port}"
#            "-port=${metricsPort}"
#          ];
#        };
#      };

      task."${name}" = {
        driver = "docker";
        vault = { };

        volumeMounts = [
          {
            volume = "minecraft-data";
            destination = "/data";
            readOnly = false;
          }
        ];

        config = {
          image = "${image}:${version}";
          ports = [ "game" ];
        };

        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);
        };

        env = {
          EULA = "TRUE";
          DIFFICULTY = "normal";
          MODE = "creative";
          MAX_PLAYERS = "2";
          MEMORY = "2G";
          ONLINE_MODE = "false";
          MOTD = "D'COTTA";
          VIEW_DISTANCE = "24";

          TYPE = "FABRIC";
          VERSION = "1.20.1";
          #          MODRINTH_PROJECTS = ''
          #            fabric-api
          #            ait
          #            indium
          #            sodium
          #            amblekit
          #            yacl
          #            immersiveportals
          #          '';
          MODRINTH_PROJECTS = ''
            fabric-api
            tardis-refined
            sodium
          '';
          #immersiveportals
        };
      };
    };
  };
}
