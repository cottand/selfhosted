let
  lib = (import ./lib) { };
  version = "latest-v24.3";
  cache = "70MB";
  maxSqlMem = "${toString (mem * 0.5)}MB";
  cpu = 1200;
  mem = 1500;
  rpcPort = 26257;
  webPort = 8080;
  sqlPort = 5432;
  bind = "0.0.0.0";
  binds = {
    hez1 = 2801;
    hez2 = 2801;
    hez3 = 2801;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.10 * cpu;
    memoryMB = 0.10 * mem;
    memoryMaxMB = 0.10 * mem + 100;
  };
  seconds = 1000000000;
  advertiseOf = {
    hez1 = "10.0.1.1:2801";
    #    hez1 = "hez1.${lib.tailscaleDns}:2801";
    #    hez2 = "hez2.${lib.tailscaleDns}:2801";
    hez2 = "10.0.1.2:2801";
    hez3 = "10.0.1.3:2801";
    #    hez3 = "hez3.${lib.tailscaleDns}:2801";
  };
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
  mkConfig = node: peers: {
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
      inherit (lib.defaults.dns) servers;
      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; to = webPort; hostNetwork = "ts"; }
        { label = "health"; hostNetwork = "ts"; }
      ];
      reservedPorts = [
        { label = "rpc"; value = binds.${node}; hostNetwork = "ts"; }
        { label = "rpc-local"; value = binds.${node}; hostNetwork = "local-hetzner"; }
      ];
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
          "traefik.tcp.routers.roach-db.rule=HostSNI(`roach-db.traefik`) || HostSNI(`roach-db.tfk.nd`)"
          "traefik.tcp.routers.roach-db.entrypoints=sql"
        ];
        checks = [
        {
          name = "health-ready";
          path = "/health?ready=1";
          tlsSkipVerify = true;
          type = "http";
          portLabel = "metrics";
          interval = 5 * lib.seconds;
          timeout = 1 * lib.seconds;
          # we want nomad to ignore this, it's traefik
          # that should respect the check
          onUpdate = "ignore";
        }
        {
          name = "health";
          path = "/health";
          tlsSkipVerify = true;
          type = "http";
          portLabel = "metrics";
          interval = 5 * lib.seconds;
          timeout = 1 * lib.seconds;
          onUpdate = "require_healthy";
        }
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
          "traefik.tcp.routers.roach-web.tls.passthrough=true"
          "traefik.tcp.routers.roach-web.rule=HostSNI(`roach-web.traefik`) || HostSNI(`roach-web.tfk.nd`)"
          "traefik.tcp.routers.roach-web.entrypoints=web,websecure"

        ];
      }
      {
        name = "roach-rpc";
        portLabel = toString rpcPort;
        #        connect.sidecarService = { };
      }
      {
        name = "${node}-roach-rpc";
        portLabel = toString rpcPort;
        taskName = "roach";
      }
      {
        name = "roach-metrics";
        portLabel = toString webPort;
        taskName = "roach";
        connect = {
          sidecarService.proxy = { };
          sidecarTask.resources = sidecarResources;
        };
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
          "--advertise-addr=${advertiseOf.${node}}"
          # peers must match constraint above
          "--join=${builtins.concatStringsSep "," (map (p: advertiseOf.${p}) peers)}"
          "--listen-addr=${bind}:${toString binds.${node}}"
          "--cache=${cache}"
          "--max-sql-memory=${maxSqlMem}"
          "--sql-addr=${bind}:${toString sqlPort}"
          "--advertise-sql-addr=roach-db.traefik:${toString sqlPort}"
          "--http-addr=0.0.0.0:${toString webPort}"
          "--store=/roach"
          "--certs-dir=/secrets"
          "--logtostderr"
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
      ] ++ builtins.concatLists (map certsForUser [ "root" "grafana" ]);
    }];
  };
in
{
  job = {
    ui = {
      description = "Distributed HA pSQL-like DB";
      links = [
        { label = "Grafana for Job"; url = "https://grafana.tfk.nd/d/de0ri7g2kukn4a/nomad-job?var-client=All&var-job=roach&var-group=All&var-task=All&var-alloc_id=All"; }
        { label = "Roach UI"; url = "https://roach-web.tfk.nd"; }
        { label = "Roach SQL Grafana"; url = "https://grafana.tfk.nd/d/crdb-console-sql/roach-sql?orgId=1&refresh=30s"; }
      ];
    };
    name = "roach";
    id = "roach";
    datacenters = [ "*" ];
    update = {
      maxParallel = 1;
      stagger = 12 * seconds;
    };
    taskGroups = [
      # cockroach node decommission 5 --certs-dir /secrets --host miki.mesh.dcotta.eu:2801
      (mkConfig "hez1" [ "hez2" "hez3" ])
      (mkConfig "hez2" [ "hez1" "hez3" ])
      (mkConfig "hez3" [ "hez1" "hez2" ])

      # add nodes here (miki?) to perform DB node migrations as you need 4 nodes to decommission
    ];
  };
}
