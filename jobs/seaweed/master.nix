let
  lib = import ./lib;
  version = "3.59";
  cpu = 100;
  mem = 200;
  ports = {
    http = 9333;
    grpc = ports.http + 10000;
    metrics = 12345;
  };
  advertise = "127.0.0.1";
  bind = "127.0.0.1";
  binds = {
    miki = 18001;
    maco = 18002;
    cosmo = 18003;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  seconds = 1000000000;
  advertiseOf = node: "${advertise}:${toString (binds.${node} - 10000)}";

  mkConfig = node: other1: other2: {
    name = "${node}-seaweed-master";
    count = 1;
    constraints = [{
      lTarget = "\${meta.box}";
      operand = "=";
      rTarget = node;
    }];
    # volumes."roach" = {
    #   name = "roach";
    #   type = "host";
    #   read_only = false;
    #   source = "roach";
    # };
    networks = [{
      mode = "bridge";
      dynamicPorts = [{
        label = "metrics";
        to = -1;
      }];
    }];
    services = [
      {
        name = "seaweed-master-http";
        portLabel = toString ports.http;
        taskName = "seaweed-master";
        connect = {
          sidecarService = { };
          sidecarTask.resources = sidecarResources;
        };
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.seaweed-master.entrypoints=web,websecure"
          "traefik.http.routers.seaweed-master.tls=true"
          "traefik.http.routers.seaweed-master.tls.certresolver=dcotta-vault"
        ];
      }
      {
        name = "seaweed-master-grpc";
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
          "traefik.http.routers.seaweed-master-grpc.tls.certresolver=dcotta-vault"
          "traefik.http.services.seaweed-master-grpc.loadbalancer.server.scheme=h2c"
        ];
      }
      {
        name = "${node}-master-grpc";
        portLabel = toString ports.grpc;
        taskName = "roach";
        connect = {
          sidecarService.proxy.upstreams = [
            {
              destinationName = "${other1}-roach-rpc";
              localBindPort = binds.${other1};
            }
            {
              destinationName = "${other2}-roach-rpc";
              localBindPort = binds.${other2};
            }
          ];
          sidecarTask.resources = sidecarResources // { cpu = builtins.ceil (cpu * 0.30); };
        };
      }
      rec {
        name = "seaweed-master-metrics";
        portLabel = toString ports.metrics;
        taskName = "seaweed-master";
        connect = {
          sidecarService.proxy = { };
          # sidecarService.proxy.expose.paths = [{
          #   path = meta.metrics_path;
          #   protocol = "http";
          #   localPathPort = httpPort;
          #   listenerPort = "metrics";
          # }];
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
          interval = 10 * seconds;
          timeout = 3 * seconds;
        }];
      }
    ];

    tasks = [{
      name = "seaweed-master";
      # vault.env = true;
      # vault.changeMode = "restart";
      # identities = [{
      #   audience = [ "vault.io" ];
      #   changeMode = "restart";
      #   name = "vault_default";
      #   TTL = 3600 * seconds;
      # }];
      # volumeMounts = [{
      #   volume = "roach";
      #   destination = "/roach";
      #   readOnly = false;
      # }];
      driver = "docker";
      config = {
        image = "chrislusf/seaweedfs:${version}";

        args = [
          "-logtostderr"
          "master"
          "-ip=${advertise}"
          "-ip.bind=${bind}"
          #   "-mdir=/data"
          "-mdir=\${NOMAD_TASK_DIR}/master"
          "-port=${toString ports.http}"
          "-port.grpc=${toString ports.grpc}"
          "-defaultReplication=200"
          "-metricsPort=${toString ports.metrics}"
          # peers must match constraint above
          "-peers=${advertiseOf other1},${advertiseOf other2}"
          # 1GB max volume size
          # lower=more volumes per box (easier replication)
          # higher=less splitting of large files
          "-volumeSizeLimitMB=1000"
        ];
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
          embeddedTmpl = builtins.to ''
            [master.maintenance]
            # periodically run these scripts are the same as running them from 'weed shell'
            scripts = """
              lock

              volume.configure.replication -collectionPattern immich-pictures -replication 200
                  ec.encode -fullPercent=95 -quietFor=1h -collection immich-pictures

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
            # [master.volume_growth]
            # copy_1 = 7                # create 1 x 7 = 7 actual volumes
            # copy_2 = 2                # create 2 x 6 = 12 actual volumes
            # copy_3 = 3                # create 3 x 3 = 9 actual volumes
            # copy_other = 1            # create n x 1 = n actual volumes
          '';
        }
      ];
    }];
  };
in
{
  job = {
    name = "seaweed-master";
    id = "seaweed-master";
    datacenters = [ "*" ];
    update = {
      maxParallel = 1;
      stagger = 12 * seconds;
    };
    taskGroups = [
      (mkConfig "miki" "maco" "cosmo")
      (mkConfig "maco" "miki" "cosmo")
      (mkConfig "cosmo" "miki" "maco")
    ];
  };
}
