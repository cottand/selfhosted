{ util, time, defaults, ... }:
let
  name = "seaweed-volume";
  version = "3.95";

  ports = {
    http = 7002;
    grpc = 17002;
    metrics = 9001;
    oltp = 4321;
  };
  cpu = 120;
  mem = 350;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.15 * cpu;
    memory = 0.20 * mem;
    memoryMax = 0.20 * mem + 100;
  };
in
{
  job."${name}" = {
    type = "system";

    update = {
      maxParallel = 1;
      stagger = 20 * time.second;
    };
    constraints = [{
      attribute = "\${meta.seaweedfs_volume}";
      value = "true";
      operator = "=";
    }];

    group."seaweed-volume" = {
      restart = {
        interval = 10 * time.minute;
        attempts = 6;
        delay = 15 * time.second;
        mode = "delay";
      };

      network = {
        dns.servers = defaults.dns.servers;
        mode = "bridge";
        port."metrics".hostNetwork = "ts";
        port."health".hostNetwork = "ts";
        reservedPorts = {
          "http" = { static = ports.http; hostNetwork = "ts"; };
          "grpc" = { static = ports.grpc; hostNetwork = "ts"; };
        };
      };

      volume."seaweed-volume" = {
        type = "host";
        readOnly = false;
        source = "seaweedfs-volume";
      };

      service."seaweed-volume-http" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = ports.oltp; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-seaweed-volume-http";
              otlpUpstreamPort = ports.oltp;
              protocol = "http";
            };
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
          port = "health";
          type = "http";
          path = "/status";
          interval = 15 * time.second;
          timeout = 3 * time.second;
          checkRestart = {
            limit = 3;
            grace = 120 * time.second;
            ignoreWarnings = false;
          };
        }];
      };

      service."seaweed-volume-metrics" = rec {
        port = toString ports.metrics;
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
          port = "metrics";
          type = "http";
          path = meta.metrics_path;
          interval = 10 * time.second;
          timeout = 3 * time.second;
        }];
      };

      service."seaweed-volume-grpc" = {
        port = toString ports.grpc;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = ports.oltp + 1; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-seaweed-master-grpc";
              otlpUpstreamPort = ports.oltp + 1;
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
          memory = mem;
          memoryMax = builtins.ceil (mem * 2.5);
        };
        config = {
          image = "chrislusf/seaweedfs:${version}";

          args = [
            "-logtostderr"
            "volume"
            # from master DNS and well-known ports so that job is not reset
            "-mserver=hez1.${util.tailscaleDns}:9333,hez2.${util.tailscaleDns}:9333,hez3.${util.tailscaleDns}:9333"
            "-dir=/volume"
            "-max=0"
            #"-dataCenter=\${node.datacenter}"
#            "-dataCenter=global"
            "-rack=\${node.unique.name}"
            "-ip=\${node.unique.name}.${util.tailscaleDns}"
            "-ip.bind=0.0.0.0"
            "-port=${toString ports.http}"
            "-port.grpc=${toString ports.grpc}"
            "-metricsPort=${toString ports.metrics}"
            # min free disk space. Low disk space will mark all volumes as ReadOnly.
            "-minFreeSpace=20GiB"
            # maximum numbers of volumes. If set to zero, the limit will be auto configured as free disk space divided by volume size. default "8"
            "-max=0"
            #"-publicUrl=\${node.unique.name}${util.tailscaleDns}:${toString ports.http}"

            # todo: use public URL option
          ];

          volumes = [ "config:/config" ];

          ports = [ "http" "grpc" "metrics" ];

          privileged = true;
        };
      };
    };
  };
}
