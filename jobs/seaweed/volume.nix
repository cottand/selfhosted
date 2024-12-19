# modified original from https://github.com/watsonian/seaweedfs-nomad
let
  lib = (import ./../lib) {};

  version = "3.80";

  ports = {
    http = 7002;
    grpc = 17002;
    metrics = 9001;
    oltp = 4321;
  };
  cpu = 120;
  mem = 250;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
in
lib.mkJob "seaweed-volume" {
  type = "system";

  update = {
    maxParallel = 1;
    stagger = 20 * lib.seconds;
  };
  constraint = {
    attribute = "\${meta.seaweedfs_volume}";
    value = true;
  };

  group."seaweed-volume" = {
    restart = with lib; {
      interval = 10 * minutes;
      attempts = 6;
      delay = 15 * seconds;
      mode = "delay";
    };

    network = {
      inherit (lib.defaults.dns) servers;
      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; hostNetwork = "ts"; }
        { label = "health"; hostNetwork = "ts"; }
      ];
      reservedPorts = [
        { label = "http"; value = ports.http;hostNetwork = "ts"; }
        { label = "grpc"; value = ports.grpc;hostNetwork = "ts"; }
      ];
    };

    volumes."seaweed-volume" = {
      type = "host";
      readOnly = false;
      source = "seaweedfs-volume";
    };


    service."seaweed-volume-http" = {
      port = ports.http;
      connect = {
        sidecarService.proxy.config = lib.mkEnvoyProxyConfig {
          otlpService = "proxy-seaweed-volume-http";
          otlpUpstreamPort = ports.oltp;
          protocol = "http";
        };
        sidecarTask.resources = sidecarResources;
      };
      tags = let router = "\${NOMAD_GROUP_NAME}-http-\${node.unique.name}"; in [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"

        # load-balanced as usual
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.middlewares=mesh-whitelist@file"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.rule=Host(`seaweed-volume-http.traefik`) && PathPrefix(`/seaweedfsstatic`)"

        # node specific
        "traefik.http.routers.${router}.entrypoints=web,websecure"
        "traefik.http.routers.${router}.tls=true"
        "traefik.http.routers.${router}.middlewares=mesh-whitelist@file,${router}-stripprefix"
        "traefik.http.routers.${router}.rule=Host(`seaweed-volume-http.traefik`) && PathPrefix(`/\${node.unique.name}`)"
        "traefik.http.middlewares.${router}-stripprefix.stripprefix.prefixes=/\${node.unique.name}"

        # redirect http -> https
        "traefik.http.middlewares.${router}-redirectscheme.redirectscheme.scheme=https"
        "traefik.http.middlewares.${router}-redirectscheme.redirectscheme.permanent=true"
        "traefik.http.routers.${router}-redirect.entrypoints=web,websecure"
        "traefik.http.routers.${router}-redirect.middlewares=mesh-whitelist@file,${router}-redirectscheme"
        "traefik.http.routers.${router}-redirect.rule=Host(`seaweed-volume-http.traefik`) && PathPrefix(`/\${node.unique.name}`)"

      ];
      checks = [{
        expose = true;
        name = "healthz";
        portLabel = "health";
        type = "http";
        path = "/status";
        interval = 15 * lib.seconds;
        timeout = 3 * lib.seconds;
        check_restart = {
          limit = 3;
          grace = "120s";
          ignoreWarnings = false;
        };
      }];
    };

    service."seaweed-volume-metrics" = rec {
      port = ports.metrics;
      connect = {
        sidecarService.proxy = { };
        sidecarTask.resources = sidecarResources;
      };
      meta = {
        metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        metrics_path = "/metrics";
      };
      checks = [{
        expose = true;
        name = "metrics";
        portLabel = "metrics";
        type = "http";
        path = meta.metrics_path;
        interval = 10 * lib.seconds;
        timeout = 3 * lib.seconds;
      }];
    };

    service."seaweed-volume-grpc" = {
      port = ports.grpc;
      connect = {
        sidecarService.proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = ports.oltp;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-master-grpc";
            otlpUpstreamPort = ports.oltp;
            protocol = "grpc";
          };
        };
        sidecarTask.resources = sidecarResources;
      };
    };

    task."seaweed" = {
      driver = "docker";

      volumeMounts = [{
        volume = "seaweed-volume";
        destination = "/volume";
        readOnly = false;
      }];

      resources = {
        cpu = cpu;
        memoryMB = mem;
        memoryMaxMB = builtins.ceil (mem * 2.5);
      };
      config = {
        image = "chrislusf/seaweedfs:${version}";

        args = [
          "-logtostderr"
          "volume"
          # from master DNS and well-known ports so that job is not reset
          (
            with lib;
            "-mserver=hez1.${tailscaleDns}:9333,hez2.${tailscaleDns}:9333,hez3.${tailscaleDns}:9333"
          )
          "-dir=/volume"
          "-max=0"
          "-dataCenter=\${node.datacenter}"
          "-rack=\${node.unique.name}"
          "-ip=\${NOMAD_IP_http}"
          "-ip.bind=0.0.0.0"
          "-port=${toString ports.http}"
          "-port.grpc=${toString ports.grpc}"
          "-metricsPort=${toString ports.metrics}"
          # min free disk space. Low disk space will mark all volumes as ReadOnly.
          "-minFreeSpace=20GiB"
          # maximum numbers of volumes. If set to zero, the limit will be auto configured as free disk space divided by volume size. default "8"
          "-max=0"
        ];

        volumes = [ "config:/config" ];

        ports = [ "http" "grpc" "metrics" ];

        privileged = true;
      };
    };
  };
}
