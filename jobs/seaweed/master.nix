let
  lib = (import ../lib) { };
  version = "3.80";
  cpu = 100;
  mem = 200;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  ports = rec {
    metrics = 12345;
    http = 9333;
    grpc = http + 10000;
  };

  advertiseOf = node: "${node}.${lib.tailscaleDns}:${toString ports.http}";

  mkConfig = node: other1: other2: {
    name = "${node}-seaweed-master";
    count = 1;
    constraints = [{
      lTarget = "\${meta.box}";
      operand = "=";
      rTarget = node;
    }];
    network = {
      inherit (lib.defaults.dns) servers;
      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; hostNetwork = "ts"; }
        { label = "health"; hostNetwork = "ts"; }
      ];
      reservedPorts = [
        { label = "http"; value = ports.http; hostNetwork = "ts"; }
        { label = "grpc"; value = ports.grpc; hostNetwork = "ts"; }
      ];
    };
    service."seaweed-master-http" = {
      portLabel = toString ports.http;
      taskName = "seaweed-master";
      connect = {
        sidecarService.proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = 4321;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-master-http";
            otlpUpstreamPort = 4321;
          };
        };
        sidecarTask.resources = sidecarResources;
      };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-master.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-master.tls=true"
      ];
    };
    service."seaweed-master-grpc" = {
      portLabel = toString ports.grpc;
      taskName = "seaweed-master";
      connect = {
        sidecarService = { };
        sidecarTask.resources = sidecarResources;
      };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-master-grpc.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-master-grpc.tls=true"
        "traefik.http.services.seaweed-master-grpc.loadbalancer.server.scheme=h2c"
      ];
    };
    service."seaweed-${node}-master-grpc" = {
      portLabel = toString ports.grpc;
      connect = {
        sidecarService.proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = 4322;
          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-master-${node}";
            otlpUpstreamPort = 4322;
            protocol = "grpc";
          };
        };
        sidecarTask.resources = sidecarResources // { cpu = builtins.ceil (cpu * 0.30); };
      };
    };
    service."seaweed-${node}-master-http" = {
      portLabel = toString ports.http;
      connect = {
        sidecarService.proxy = {
          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-${node}";
            otlpUpstreamPort = 4322;
          };
        };
        sidecarTask.resources = sidecarResources // { cpu = builtins.ceil (cpu * 0.30); };
      };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-master-http-${node}.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-master-http-${node}.tls=true"
      ];
      checks = [{
        expose = true;
        name = "health";
        portLabel = "health";
        type = "http";
        path = "/";
        interval = 10 * lib.seconds;
        timeout = 3 * lib.seconds;
        check_restart = {
          limit = 3;
          grace = "120s";
          ignoreWarnings = false;
        };
      }];
    };
    service."seaweed-master-metrics" = rec {
      portLabel = toString ports.metrics;
      taskName = "seaweed-master";
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

    task."seaweed-master" = {
      driver = "docker";
      config = {
        image = "chrislusf/seaweedfs:${version}";

        args = [
          "-logtostderr"
          "master"
          "-ip=${node}.${lib.tailscaleDns}"
          "-ip.bind=0.0.0.0"
          #   "-mdir=/data"
          "-mdir=\${NOMAD_TASK_DIR}/master"
          "-port=${toString ports.http}"
          "-port.grpc=${toString ports.grpc}"
          "-defaultReplication=100"
          "-metricsPort=${toString ports.metrics}"
          # peers must match constraint above
          "-peers=${advertiseOf other1},${advertiseOf other2}"
          # 1GB max volume size
          # lower=more volumes per box (easier replication)
          # higher=less splitting of large files
          "-volumeSizeLimitMB=1000"
        ];
        mounts = [{
          type = "bind";
          source = "local/master.toml";
          target = "/etc/seaweedfs/master.toml";
        }];
      };
      resources = {
        cpu = cpu;
        memoryMB = mem;
        memoryMaxMB = mem + 100;
      };
      templates = [
        {
          destPath = "local/master.toml";
          changeMode = "restart";
          embeddedTmpl = ''
            [master.maintenance]
            # periodically run these scripts are the same as running them from 'weed shell'
            scripts = """
              lock

              ec.encode -fullPercent=95 -quietFor=24h -collection=documents
              ec.encode -fullPercent=95 -quietFor=24h -collection=attic

              ec.rebuild -force
              ec.balance -force

              volume.deleteEmpty -quietFor=24h -force
              volume.balance -force
              volume.fix.replication
              s3.clean.uploads -timeAgo=24h
              unlock
            """
            # Do this in weed shell to grow buckets by 2 volumes when they are full, with replicatoin 010
            # fs.configure -locationPrefix=/buckets/ -replication=010 -volumeGrowthCount=2 -apply

            sleep_minutes = 16          # sleep minutes between each script execution

            [master.sequencer]
            type = "raft"     # Choose [raft|snowflake] type for storing the file id sequence


            # create this number of logical volumes if no more writable volumes
            # count_x means how many copies of data.
            # e.g.:
            #   000 has only one copy, copy_1
            #   010 and 001 has two copies, copy_2
            #   011 has only 3 copies, copy_3
            [master.volume_growth]
            copy_1 = 7                # create 1 x 7 = 7 actual volumes
            copy_2 = 2                # create 2 x 6 = 12 actual volumes
            copy_3 = 3                # create 3 x 3 = 9 actual volumes
            copy_other = 1            # create n x 1 = n actual volumes
          '';
        }
      ];
    };
  };
in
lib.mkJob "seaweed-master" {
  datacenters = [ "*" ];
  update = {
    maxParallel = 1;
    autoRevert = true;
    canary = 0;
    stagger = 10 * lib.seconds;
  };
  group."miki-seaweed-master" = mkConfig "hez1" "hez2" "hez3";
  group."maco-seaweed-master" = mkConfig "hez2" "hez3" "hez1";
  group."cosmo-seaweed-master" = mkConfig "hez3" "hez1" "hez2";
}
