{ util, time, defaults, ... }:
let
  name = "seaweed-filer";
  version = "3.90";
  cpu = 100;
  mem = 200;
  ports = {
    http = 8888;
    grpc = ports.http + 10000;
    metrics = 12345;
    s3 = 13210;
    webdav = 12311;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  bind = "0.0.0.0";
  otlpPort = 9001;
in
{
  job."${name}" = {
    update = {
      maxParallel = 1;
      stagger = 20 * time.second;
      autoRevert = true;
      autoPromote = true;
      canary = 1;
    };

    group."seaweed-filer" = {
      count = 2;
      network = {
        dns.servers = defaults.dns.servers;
        mode = "bridge";
        port."metrics".hostNetwork = "ts";
        port."health".hostNetwork = "ts";
        reservedPorts = {
          "http" = { static = ports.http; hostNetwork = "ts"; };
          "grpc" = { static = ports.grpc; hostNetwork = "ts"; };
          "s3" = { static = ports.s3; hostNetwork = "ts"; };
        };
      };

      service."seaweed-filer-http" = {
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
              { destinationName = "roach-db"; localBindPort = 5432; }
            ];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-seaweed-filer-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        # TODO implement http healthcheck https://github.com/seaweedfs/seaweedfs/pull/4899/files
        port = toString ports.http;
        checks = [{
          expose = true;
          name = "healthz";
          path = "/healthz";
          type = "http";
          port = "health";
          interval = 20 * time.second;
          timeout = 2 * time.second;
          checkRestart = {
            limit = 3;
            grace = 120 * time.second;
            ignoreWarnings = false;
          };
        }];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.middlewares=mesh-whitelist@file"
        ];
      };
      service."seaweed-filer-grpc" = {
        port = toString ports.grpc;
        connect.sidecarService.proxy = {
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-filer-grpc";
            otlpUpstreamPort = otlpPort;
            protocol = "tcp";
          };
        };
        connect.sidecarTask.resources = sidecarResources;
      };
      service."seaweed-filer-metrics" = rec {
        connect.sidecarService.proxy = { };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.metrics;
        checks = [{
          expose = true;
          name = "metrics";
          port = "metrics";
          type = "http";
          path = meta.metrics_path;
          interval = 10 * time.second;
          timeout = 3 * time.second;
        }];
        meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        meta.metrics_path = "/metrics";
      };
      service."seaweed-filer-s3" = {
        port = toString ports.s3;
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}-s3.tls=true"
          "traefik.http.routers.${name}-s3.entrypoints=web,websecure"
        ];

        connect.sidecarTask.resources = sidecarResources;
        connect.sidecarService.proxy.config = util.mkEnvoyProxyConfig {
          otlpService = "proxy-seaweed-filer-s3";
          otlpUpstreamPort = otlpPort;
          protocol = "http";
        };
      };

      task."seaweed-filer" = {
        driver = "docker";

        config = {
          image = "chrislusf/seaweedfs:${version}";
          # ports = ["http" "grpc", "metrics", "webdav"];
          args = [
            "-logtostderr"
            "filer"
            # advertise node on tailscale so that master can find filer
            "-ip=\${attr.unique.hostname}.${util.tailscaleDns}"
            "-ip.bind=${bind}"
            "-master=hez1.${util.tailscaleDns}:9333,hez2.${util.tailscaleDns}:9333,hez3.${util.tailscaleDns}:9333"
            "-port=${toString ports.http}"
            "-port.grpc=${toString ports.grpc}"
            "-metricsPort=${toString ports.metrics}"
            "-s3"
            "-s3.port=${toString ports.s3}"
            "-s3.allowEmptyFolder=false"
            # see https://github.com/seaweedfs/seaweedfs/issues/3886#issuecomment-1769880124
            # "-dataCenter=\${node.datacenter}"
            # "-rack=\${node.unique.name}"
          ];
          mounts = [{
            type = "bind";
            source = "local/filer.toml";
            target = "/etc/seaweedfs/filer.toml";
          }];
        };
        vault = { };

        resources = {
          cpu = cpu;
          memory = mem;
        };
        templates = [{
          destination = "local/filer.toml";
          changeMode = "restart";
          data = ''
            # Put this file to one of the location, with descending priority
            #    ./filer.toml
            #    $HOME/.seaweedfs/filer.toml
            #    /etc/seaweedfs/filer.toml

            # Customizable filer server options

            [filer.options]
            # recursive_delete will delete all sub folders and files, similar to "rm -Rf"
            recursive_delete = true

            [postgres2]
              enabled = true
              createTable = """
                CREATE TABLE IF NOT EXISTS "%s" (
                  dirhash   BIGINT,
                  name      VARCHAR(65535),
                  directory VARCHAR(65535),
                  meta      bytea,
                  PRIMARY KEY (dirhash, name)
                );
              """
              hostname = "localhost"
              port = 5432
              username = "seaweed_filer"
              password = "{{with secret "secret/data/nomad/job/seaweed-filer/db"}}{{.Data.data.password}}{{end}}"
              database = "seaweed_filer" 
              schema = ""
              sslmode = "require"
              connection_max_idle = 100
              connection_max_open = 100
              connection_max_lifetime_seconds = 0
          '';
        }];
      };
    };
  };
}
