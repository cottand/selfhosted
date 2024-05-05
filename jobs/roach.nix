let
  version = "latest-v23.1";
  cache = "70MB";
  maxSqlMem = "${toString (mem * 0.5)}MB";
  cpu = 500;
  mem = 600;
  rpcPort = 26257;
  webPort = 8080;
  sqlPort = 5432;
  bind = "127.0.0.1";
  binds = {
    miki = 8001;
    maco = 8002;
    cosmo = 8003;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.10 * cpu;
    memoryMB = 0.10 * mem;
    memoryMaxMB = 0.10 * mem + 100;
  };
  advertise = "127.0.0.1";
  seconds = 1000000000;
  advertiseOf = node: "${advertise}:${toString binds.${node}}";
  certsForUser = name: [
    {
      destPath = "/secrets/client.${name}.key";
      changeMode = "restart";
      embeddedTmpl = ''
        {{with secret "secret/data/nomad/job/roach/users/${name}"}}{{.Data.data.key}}{{end}}
      '';
      perms = "0600";
    }
    {
      destPath = "/secrets/client.${name}.crt";
      changeMode = "restart";
      embeddedTmpl = ''
        {{with secret "secret/data/nomad/job/roach/users/${name}"}}{{.Data.data.chain}}{{end}}
      '';
      perms = "0600";
    }
  ];
  mkConfig = node: other1: other2: {
    name = "${node}-roach";
    count = 1;
    constraints = [{
      lTarget = "\${meta.box}";
      operand = "=";
      rTarget = node;
    }];
    volumes."roach" = {
      name = "roach";
      type = "host";
      readOnly = false;
      source = "roach";
    };
    networks = [{
      mode = "bridge";
      dynamicPorts = [{
        label = "metrics";
        to = webPort;
      }];
    }];
    services = [
      {
        name = "roach-db";
        portLabel = toString sqlPort;
        connect = {
          sidecarService = { };
          sidecarTask.resources = sidecarResources;
        };
        taskName = "roach";
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.tcp.routers.roach-db.tls.passthrough=true"
          "traefik.tcp.routers.roach-db.rule=HostSNI(`roach-db.traefik`)"
          "traefik.tcp.routers.roach-db.entrypoints=sql"
        ];
      }
      {
        name = "roach-web";
        portLabel = toString webPort;
        taskName = "roach";
        connect = {
          sidecarService = { };
          sidecarTask.resources = sidecarResources;
        };
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.tcp.routers.roach-web.entrypoints=web,websecure"
          "traefik.tcp.routers.roach-web.tls.passthrough=true"
          "traefik.tcp.routers.roach-web.rule=HostSNI(`roach-web.traefik`)"
        ];
      }
      # {
      #   name = "roach-rpc";
      #   # portLabel = "rpc";
      #   portLabel = toString rpcPort;
      #   connect.sidecarService = { };
      # }
      {
        name = "${node}-roach-rpc";
        portLabel = toString rpcPort;
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
      {
        name = "roach-metrics";
        portLabel = toString webPort;
        taskName = "roach";
        connect = {
          sidecarService.proxy = { };
          sidecarTask.resources = sidecarResources;
        };
        # cockroachdb's metrics dashboards assume a job called cockroachdb, which is not our case :'c
         meta = {
           metrics_port = "\${NOMAD_HOST_PORT_metrics}";
           metrics_path = "/_status/vars";
         };
      }
    ];

    tasks = [{
      name = "roach";
      vault.env = true;
      vault.changeMode = "restart";
      identities = [{
        audience = [ "vault.io" ];
        changeMode = "restart";
        name = "roach";
        TTL = 3600 * seconds;
        # "Env": true
        # "File": true,
      }];
      volumeMounts = [{
        volume = "roach";
        destination = "/roach";
        readOnly = false;
      }];
      driver = "docker";
      config = {
        image = "cockroachdb/cockroach:${version}";
        args = [
          "start"
          "--advertise-addr=${advertiseOf node}"
          # peers must match constraint above
          "--join=${advertiseOf other1},${advertiseOf other2}"
          "--listen-addr=${bind}:${toString rpcPort}"
          "--cache=${cache}"
          "--max-sql-memory=${maxSqlMem}"
          "--sql-addr=${bind}:${toString sqlPort}"
          "--advertise-sql-addr=roach-db.traefik:${toString sqlPort}"
          "--http-addr=0.0.0.0:${toString webPort}"
          "--store=/roach"
          "--certs-dir=/secrets"
        ];
      };
      resources = {
        cpu = cpu;
        memoryMB = mem;
        memoryMaxMB = mem + 100;
      };
      templates = [
        {
          destPath = "/secrets/ca.crt";
          changeMode = "restart";
          embeddedTmpl = ''
            {{with secret "secret/data/nomad/job/roach/cert"}}{{.Data.data.ca}}{{end}}
          '';
        }
        {
          destPath = "/secrets/node.crt";
          changeMode = "restart";
          embeddedTmpl = ''
            {{with secret "secret/data/nomad/job/roach/cert"}}{{.Data.data.chain}}{{end}}
          '';
        }
        {
          destPath = "/secrets/node.key";
          changeMode = "restart";
          embeddedTmpl = ''
            {{with secret "secret/data/nomad/job/roach/cert"}}{{.Data.data.key}}{{end}}
          '';
          perms = "0600";
        }
      ] ++ builtins.concatLists (builtins.map certsForUser [ "root" "grafana" ]);
    }];
  };
in
{
  job = {
    name = "roach";
    id = "roach";
    datacenters = [ "*" ];
    updatePolicy = {
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
