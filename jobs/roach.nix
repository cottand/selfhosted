{ util, time, defaults, ... }:
let
  version = "v24.3.17";
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
    memory = 0.10 * mem;
    memoryMax = 0.10 * mem + 100;
  };
  seconds = 1000000000;
  advertiseOf = {
    hez1 = "10.0.1.1:2801";
    hez2 = "10.0.1.2:2801";
    hez3 = "10.0.1.3:2801";
  };
  certsForUser = name: [
    {
      destination = "/secrets/client.${name}.key";
      changeMode = "restart";
      data = ''
        {{with secret "secret/data/nomad/job/roach/users/${name}"}}{{.Data.data.key}}{{end}}
      '';
      perms = "0600";
    }
    {
      destination = "/secrets/client.${name}.crt";
      changeMode = "restart";
      data = ''
        {{with secret "secret/data/nomad/job/roach/users/${name}"}}{{.Data.data.chain}}{{end}}
      '';
      perms = "0600";
    }
  ];
  mkConfig = node: peers: {
    name = "${node}-roach";
    count = 1;
    constraints = [{
      attribute = "\${meta.box}";
      operator = "=";
      value = node;
    }];
    volume."roach" = {
      name = "roach";
      type = "host";
      readOnly = false;
      source = "roach";
    };
    network = {
      inherit (defaults) dns;
      mode = "bridge";
      port."metrics" = { to = webPort; hostNetwork = "ts"; };
      port."health".hostNetwork = "ts";
      
      reservedPorts = {
        "rpc" = { static = binds.${node}; hostNetwork = "ts"; };
        "rpc-local" = { static = binds.${node}; hostNetwork = "local-hetzner"; };
      };
    };
    service."roach-db" = {
      port = toString sqlPort;
      connect = {
        sidecarService = { };
        sidecarTask.resources = sidecarResources;
      };
      task = "roach";
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
          port = "metrics";
          interval = 5 * time.second;
          timeout = 1 * time.second;
          # we want nomad to ignore this, it's traefik
          # that should respect the check
          onUpdate = "ignore";
        }
        {
          name = "health";
          path = "/health";
          tlsSkipVerify = true;
          type = "http";
          port = "metrics";
          interval = 5 * time.second;
          timeout = 1 * time.second;
          onUpdate = "require_healthy";
        }
      ];
    };
    service."roach-web" = {
      port = toString webPort;
      task = "roach";
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
    };
    service."roach-rpc" = {
      name = "roach-rpc";
      port = toString rpcPort;
      #        connect.sidecarService = { };
    };
    service."${node}-roach-rpc" = {
      name = "${node}-roach-rpc";
      port = toString rpcPort;
      task = "roach";
    };
    service."roach-metrics" = {
      port = toString webPort;
      task = "roach";
      connect = {
        sidecarService.proxy = { };
        sidecarTask.resources = sidecarResources;
      };
      meta = {
        metrics_port = "\${NOMAD_HOST_PORT_metrics}";
        metrics_path = "/_status/vars";
      };
    };

    task."roach" = {
      vault.env = true;
      vault.changeMode = "restart";
      identities = [{
        aud = [ "vault.io" ];
        changeMode = "restart";
        name = "roach";
        ttl = 3600 * seconds;
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
        memory = mem;
        memoryMax = mem + 100;
      };
      templates = [
        {
          destination = "/secrets/ca.crt";
          changeMode = "restart";
          data = ''
            {{with secret "secret/data/nomad/job/roach/cert"}}{{.Data.data.ca}}{{end}}
          '';
        }
        {
          destination = "/secrets/node.crt";
          changeMode = "restart";
          data = ''
            {{with secret "secret/data/nomad/job/roach/cert"}}{{.Data.data.chain}}{{end}}
          '';
        }
        {
          destination = "/secrets/node.key";
          changeMode = "restart";
          data = ''
            {{with secret "secret/data/nomad/job/roach/cert"}}{{.Data.data.key}}{{end}}
          '';
          perms = "0600";
        }
      ] ++ builtins.concatLists (map certsForUser [ "root" "grafana" ]);
    };
  };
in
{
  job."roach" = {
    ui = {
      description = "Distributed HA pSQL-like DB";
      links = [
        { label = "Roach UI"; url = "https://roach-web.tfk.nd"; }
        { label = "Roach SQL Grafana"; url = "https://grafana.tfk.nd/d/crdb-console-sql/roach-sql?orgId=1&refresh=30s"; }
      ];
    };
    update = {
      maxParallel = 1;
      stagger = 12 * seconds;
    };
    # cockroach node decommission 5 --certs-dir /secrets --host miki.mesh.dcotta.eu:2801
    group."hez1-roach" = mkConfig "hez1" [ "hez2" "hez3" ];
    group."hez2-roach" = mkConfig "hez2" [ "hez1" "hez3" ];
    group."hez3-roach" = mkConfig "hez3" [ "hez1" "hez2" ];
    # add nodes here (miki?) to perform DB node migrations as you need 4 nodes to decommission
  };
}
