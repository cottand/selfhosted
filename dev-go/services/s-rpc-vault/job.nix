{ version ? "d43fc34"
, ...
}:
let
  lib = (import ../../../jobs/lib) { };
  name = builtins.baseNameOf ./.;
  ports = {
    http = 8080;
    grpc = 8081;
    upDb = 5432;
  };
  resources = {
    cpu = 100;
    memoryMB = 150;
    memoryMaxMB = 400;
  };
  sidecarResources = lib.mkSidecarResourcesWithFactor 0.20 resources;
  otlpPort = 9001;
in
lib.mkJob name {
  update = {
    maxParallel = 2;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
    stagger = 10 * lib.seconds;
  };

  meta.version = version;

  group.${name} = {
    count = 2;
    network = {
      inherit (lib.defaults.dns) servers;

      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; hostNetwork = "ts"; }
      ];
      reservedPorts = [ ];
    };

    volumes."ca-certificates" = rec {
      name = "ca-certificates";
      type = "host";
      readOnly = true;
      source = name;
    };
    service."${name}-metrics-http" = rec {
      connect.sidecarService.proxy = { };
      connect.sidecarTask.resources = sidecarResources;
      port = toString ports.http;
      meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      meta.metrics_path = "/metrics";
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
    service."${name}-grpc" = {
      connect.sidecarService.proxy = {
        upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
        upstream."roach-db".localBindPort = ports.upDb;

        config = lib.mkEnvoyProxyConfig {
          otlpService = "proxy-${name}-grpc";
          otlpUpstreamPort = otlpPort;
          extra.local_request_timeout_ms = 60 * 1000;
          extra.protocol = "grpc";
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      port = toString ports.grpc;
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.protocol=h2c"
        "traefik.http.routers.${name}-grpc.tls=true"
        "traefik.http.routers.${name}-grpc.entrypoints=web, websecure"
        "traefik.http.services.${name}-grpc.loadbalancer.server.scheme=h2c"
      ];
    };

    task.${name} = {
      inherit resources;
      driver = "docker";
      vault = { };

      config = {
        image = "ghcr.io/cottand/selfhosted/${name}:${version}";
      };
      env = {
        HTTP_HOST = lib.localhost;
        HTTP_PORT = toString ports.http;
        GRPC_PORT = toString ports.grpc;
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:${toString otlpPort}";
        OTEL_SERVICE_NAME = name;
        DCOTTACOM_VERSION = version;
      };
      template."db-env" = {
        changeMode = "restart";
        envvars = true;
        embeddedTmpl = ''
          {{with secret "secret/data/services/db-rw-default"}}
          CRDB_CONN_URL="postgres://{{.Data.data.username}}:{{.Data.data.password}}@localhost:${toString ports.upDb}/services?ssl_sni=roach-db.traefik"
          {{end}}
        '';
      };
      volumeMounts = [{
        volume = "ca-certificates";
        destination = "/etc/ssl/certs";
        readOnly = true;
        propagationMode = "host-to-task";
      }];
      vault.env = true;
      vault.role = name; # or services-default
      vault.changeMode = "restart";
      identities = [{
        env = true;
        changeMode = "restart";
        ttl = 12 * lib.hours;
      }];
    };
  };
}
