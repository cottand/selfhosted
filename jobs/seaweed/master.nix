{ util, time, defaults, ... }:
let
  version = "3.90";
  cpu = 100;
  mem = 200;
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  ports = rec {
    metrics = 12345;
    http = 9333;
    grpc = http + 10000;
  };
  advertiseOf = node: "${node}.${util.tailscaleDns}:${toString ports.http}";

  mkConfig = node: other1: other2: {
    name = "${node}-seaweed-master";
    count = 1;
    constraints = [{
      attribute = "\${meta.box}";
      operator = "=";
      value = node;
    }];
    network = {
      mode = "bridge";
      port."metrics".hostNetwork = "ts";
      port."health".hostNetwork = "ts";
      reservedPorts = {
        "http" = { static = ports.http; hostNetwork = "ts"; };
        "grpc" = { static = ports.grpc; hostNetwork = "ts"; };
      };
      dns.servers = [ "100.100.100.100" ];
    };
    service."seaweed-master-http" = {
      port = toString ports.http;
      connect.sidecarService = {
        proxy = {
          upstreams = [
            { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = 4321; }
          ];

          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-master-http";
            otlpUpstreamPort = 4321;
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-master.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-master.tls=true"
      ];
    };
    service."seaweed-master-grpc" = {
      port = toString ports.grpc;
      connect.sidecarService = { };
      connect.sidecarTask.resources = sidecarResources;
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-master-grpc.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-master-grpc.tls=true"
        "traefik.http.services.seaweed-master-grpc.loadbalancer.server.scheme=h2c"
      ];
    };
    service."seaweed-${node}-master-grpc" = {
      port = toString ports.grpc;
      connect.sidecarService = {
        proxy = {
          upstreams = [
            { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = 4322; }
          ];
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-master-${node}";
            otlpUpstreamPort = 4322;
            protocol = "grpc";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources // { cpu = builtins.ceil (cpu * 0.30); };
    };
    service."seaweed-${node}-master-http" = {
      port = toString ports.http;
      connect.sidecarService = {
        proxy = {
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-${node}";
            otlpUpstreamPort = 4322;
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources // { cpu = builtins.ceil (cpu * 0.30); };
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.seaweed-master-http-${node}.entrypoints=web,websecure"
        "traefik.http.routers.seaweed-master-http-${node}.tls=true"
      ];
      checks = [{
        expose = true;
        name = "health";
        port = "health";
        type = "http";
        path = "/";
        interval = 10 * time.second;
        timeout = 3 * time.second;
        checkRestart = {
          limit = 3;
          grace = 120 * time.second;
          ignoreWarnings = false;
        };
      }];
    };
    service."seaweed-master-metrics" = rec {
      port = toString ports.metrics;
      connect.sidecarService.proxy = { };
      connect.sidecarTask.resources = sidecarResources;
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

    task."seaweed-master" = {
      driver = "docker";
      config = {
        image = "chrislusf/seaweedfs:${version}";

        args = [
          "-logtostderr"
          "master"
          "-ip=${node}.${util.tailscaleDns}"
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
        memory = mem;
        memoryMax = mem + 100;
      };
      templates = [
        {
          destination = "local/master.toml";
          changeMode = "restart";
          data = ''
            [master.maintenance]
            # periodically run these scripts are the same as running them from 'weed shell'
            scripts = """
              lock

              # hosted only on london for speed
              fs.configure -locationPrefix=/buckets/attic -replication=010 -dataCenter london-home -volumeGrowthCount=4 -fsync=true -apply

              fs.configure -locationPrefix=/buckets/documents -replication=100 -volumeGrowthCount=2 -fsync=true -apply
              fs.configure -locationPrefix=/buckets/documents/domestic -replication=101 -volumeGrowthCount=2 -fsync=true -apply

              fs.configure -locationPrefix=/buckets/immich-pictures -replication=100 -volumeGrowthCount=2 -fsync=true -apply


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
{
  job."seaweed-master" = {
    datacenters = [ "*" ];
    update = {
      maxParallel = 1;
      autoRevert = true;
      canary = 0;
      stagger = 10 * time.second;
    };
    group."miki-seaweed-master" = mkConfig "hez1" "hez2" "hez3";
    group."maco-seaweed-master" = mkConfig "hez2" "hez3" "hez1";
    group."cosmo-seaweed-master" = mkConfig "hez3" "hez1" "hez2";
  };
}
