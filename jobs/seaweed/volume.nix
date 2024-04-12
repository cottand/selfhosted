# modified original from https://github.com/watsonian/seaweedfs-nomad
let
  lib = import ./../lib;

  ports = {
    http = 7002;
    grpc = 17002;
    metrics = 9001;
    oltp = 4321;
  };
  upstreamPorts = {
    miki = 9334;
    maco = 9335;
    cosmo = 9336;
  };

  cpu = 100;
  mem = 200;
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
    stagger = 15 * lib.seconds;
  };
  constraint = {
    attribute = "\${meta.seaweedfs_volume}";
    value = true;
  };

  group."seaweed-volume" = {
    restart = {
      interval = "10m";
      attempts = 6;
      delay = "15s";
      mode = "delay";
    };

    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; }
      ];
      reservedPorts = [
        { label = "http"; value = ports.http; }
        { label = "grpc"; value = ports.grpc; }
      ];
    };

    volume."seaweedfs-volume" = {
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
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls.certresolver=dcotta-vault"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.middlewares=mesh-whitelist@file"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.rule=Host(`seaweed-volume-http.traefik`)"

        # node specific
        "traefik.http.routers.${router}.entrypoints=web,websecure"
        "traefik.http.routers.${router}.tls=true"
        "traefik.http.routers.${router}.tls.certresolver=dcotta-vault"
        "traefik.http.routers.${router}.middlewares=mesh-whitelist@file,${router}-stripprefix"
        "traefik.http.routers.${router}.rule=Host(`seaweed-volume-http.traefik`) && PathPrefix(`/\${node.unique.name}`)"
        "traefik.http.middlewares.${router}-stripprefix.stripprefix.prefixes=/\${node.unique.name}"

        # redirect http -> https
        "traefik.http.middlewares.${router}-redirectscheme.redirectscheme.scheme=https"
        "traefik.http.middlewares.${router}-redirectscheme.redirectscheme.permanent=true"
        "traefik.http.routers.${router}-http.entrypoints=web,websecure"
        "traefik.http.routers.${router}-http.middlewares=mesh-whitelist@file,${router}-redirectscheme"
        "traefik.http.routers.${router}-http.rule=Host(`seaweed-volume-http.traefik`) && PathPrefix(`/\${node.unique.name}`)"

      ];
      check = {
        expose = true;
        name = "healthz";
        port = "http";
        type = "http";
        path = "/status";
        interval = "20s";
        timeout = "5s";
        check_restart = {
          limit = 3;
          grace = "120s";
          ignoreWarnings = false;
        };
      };
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
          upstream."seaweed-miki-master-grpc".localBindPort = 19334;
          upstream."seaweed-maco-master-grpc".localBindPort = 19335;
          upstream."seaweed-cosmo-master-grpc".localBindPort = 19336;
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

      volumeMount = {
        volume = "seaweedfs-volume";
        destination = "/data";
        readOnly = false;
      };

      resources = {
        cpu = cpu;
        memoryMB = mem;
        memoryMaxMB = builtins.ceil (mem * 1.2);
      };
      config = {
        image = "chrislusf/seaweedfs:3.62";

        args = [
          "-logtostderr"
          "volume"
          # from master DNS and well-known ports so that job is not reset
          (
            with (builtins.mapAttrs (_: toString) upstreamPorts);
            "-mserver=localhost:${cosmo},localhost:${miki},localhost:${maco}"
          )
          "-dir=/data/\${node.unique.name}"
          "-dir=/data"
          "-max=0"
          "-dataCenter=\${node.datacenter}"
          "-rack=\${node.unique.name}"
          "-ip=\${NOMAD_IP_http}"
          "-publicUrl=seaweed-volume-http.traefik/\${node.unique.name}"
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
