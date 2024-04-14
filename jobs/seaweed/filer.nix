let
  lib = import ../lib;
  version = "3.64";
  cpu = 100;
  mem = 200;
  ports = {
    http = 8888;
    grpc = ports.http + 10000;
    metrics = 12345;
    s3 = 13210;
    webdav = 12311;
  };
  upstreamPorts = {
    miki = 9334;
    maco = 9335;
    cosmo = 9336;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  bind = "127.0.0.1";
  otlpPort = 9001;
in
lib.mkJob "seaweed-filer" {

  update = {
    maxParallel = 1;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
  };

  group."seaweed-filer" = {
    count = 3;
    network = {
      mode = "bridge";

      port."http" = { };
      port."grpc" = { };
      dynamicPorts = [
        { label = "metrics"; }
      ];
    };

    service."seaweed-filer-http" = {
      connect.sidecarService = {
        proxy = {

          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;

          upstream."roach-db".localBindPort = 5432;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-web-portfolio";
            otlpUpstreamPort = otlpPort;
            protocol = "tcp";
          };
        };
      };
      # TODO implement http healthcheck https://github.com/seaweedfs/seaweedfs/pull/4899/files
      port = toString ports.http;
      check = {
        name = "alive";
        type = "tcp";
        port = "http";
        interval = "20s";
        timeout = "2s";
      };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.tls.certresolver=dcotta-vault"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-http.middlewares=mesh-whitelist@file"
      ];
    };
    service."seaweedfs-filer-grpc" = {
      port = toString ports.grpc;
      check = {
        name = "alive";
        type = "tcp";
        port = "grpc";
        interval = "20s";
        timeout = "2s";
      };
      connect. sidecarService.proxy = {
        upstream."seaweed-miki-master-grpc".localBindPort = 19334;
        upstream."seaweed-maco-master-grpc".localBindPort = 19335;
        upstream."seaweed-cosmo-master-grpc".localBindPort = 19336;

        config = lib.mkEnvoyProxyConfig {
          otlpService = "proxy-seaweed-filer-grpc";
          otlpUpstreamPort = otlpPort;
          protocol = "grpc";
        };
      };
    };
    service."seaweedfs-webdav" = {
      port = toString ports.webdav;
      check = {
        name = "alive";
        type = "tcp";
        port = "webdav";
        interval = "20s";
        timeout = "2s";
      };
    };
    service."seaweedfs-filer-metrics" = {
      connect.sidecarService.proxy = { };
      sidecarTask.resources = sidecarResources;
      port = toString ports.metrics;
      checks = [{
        expose = true;
        name = "metrics";
        port = "metrics";
        type = "http";
        path = "/metrics";
        interval = 10 * lib.seconds;
        timeout = 3 * lib.seconds;
      }];
      meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      meta.metrics_path = "/metrics";
    };
    service. "seaweedfs-filer-s3" = {
      port = toString ports.s3;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-s3.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-s3.middlewares=vpn-whitelist@file"
      ];
    };


    task."seaweed-filer" = {
      driver = "docker";

      config = {
        image = "chrislusf/seaweedfs:${version}";
        # ports = ["http" "grpc", "metrics", "webdav"];
        args = [
          "-logtostderr"
          "filer"
          "-ip=${bind}"
          "-ip.bind=${bind}"
          (
            with (builtins.mapAttrs (_: toString) upstreamPorts);
            "-master=localhost:${cosmo},localhost:${miki},localhost:${maco}"
          )
          "-port=${toString ports.http}"
          "-port.grpc=${toString ports.grpc}"
          "-metricsPort=${toString ports.metrics}"
          # "-webdav"
          # "-webdav.collection="
          # "-webdav.replication=010"
          # "-webdav.port=${toString ports.webdav}"
          "-s3"
          "-s3.port=${toString ports.s3}"
          "-s3.allowEmptyFolder=false"
        ];
        mounts = [{
          type = "bind";
          source = "local/filer.toml";
          target = "/etc/seaweedfs/filer.toml";
        }];
      };

      resources = {
        cpu = cpu;
        memory = mem;
      };
      template."local/filer.toml" = {
        changeMode = "restart";
        embeddedTmpl = ''
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
            password = "_"
            database = "seaweed_filer" 
            schema = ""
            sslmode = "require"
            connection_max_idle = 100
            connection_max_open = 100
            connection_max_lifetime_seconds = 0
        '';
      };
    };
  };
}
