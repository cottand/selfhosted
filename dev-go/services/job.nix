{ version ? "d43fc34"
, ...
}:
let
  lib = (import ../../jobs/lib) { };
  name = "services-go";
  cpu = 100;
  mem = 200;
  ports = {
    http = 8080;
    grpc = 8081;
    upDb = 5432;
  };
  resources = {
    cpu = cpu;
    memoryMB = mem;
    memoryMaxMB = builtins.ceil (2 * mem);
  };
  sidecarResources = lib.mkSidecarResourcesWithFactor 0.15 resources;
  otlpPort = 9001;
in
lib.mkJob name {
  update = {
    maxParallel = 2;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
    stagger = 5 * lib.seconds;
  };

  group.${name} = {
    count = 3;
    network = {
      inherit (lib.defaults.dns) servers;

      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; hostNetwork = "ts"; }
      ];
      reservedPorts = [ ];
    };

    service."${name}-http" = rec {
      connect.sidecarService = {
        proxy = {
          upstream."tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          upstream."roach-db".localBindPort = ports.upDb;

          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-${name}-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
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
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
      ];
    };

    service."s-web-portfolio-http" = (import ./s-web-portfolio/consulService.nix) { inherit lib sidecarResources; };
    service."s-web-github-webhook-http" = (import ./s-web-github-webhook/consulService.nix) { inherit lib sidecarResources; };

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
        SELFHOSTED_SSL_ROOT_CA = "/local/root_ca.crt";
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
      template."ssl-root-ca" = {
        changeMode = "restart";
        destPath = "local/root_ca.crt";
        embeddedTmpl = ''
          {{- with secret "secret/data/nomad/infra/root_ca" -}}{{ .Data.data.value }}{{- end -}}
        '';
      };
      vault.env = true;
      vault.role = "service-db-rw-default";
      vault.changeMode = "restart";
      identities = [{
        env = true;
        changeMode = "restart";
        ttl = 12 * lib.hours;
      }];
    };
  };
}
