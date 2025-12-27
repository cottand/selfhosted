#{ version ? "d43fc34"
#, ...
#}:
{ self, time, util, defaults, ... }:
let
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
    memory = mem;
    memoryMax = builtins.ceil (2 * mem);
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 resources;
  otlpPort = 9001;
  version = self.inputs.nixpkgs.lib.strings.removeSuffix "-dirty" (self.shortRev or self.dirtyShortRev or "d43fc34");
in
{
  imports = [
    ./s-web-portfolio/consulService.nix
    ./s-web-github-webhook/consulService.nix
  ];
  job.${name} = {
    update = {
      maxParallel = 2;
      autoRevert = true;
      autoPromote = true;
      canary = 1;

      stagger = 5 * time.second;
    };

    meta.version = version;

    group.${name} = {
      count = 3;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."metrics".hostNetwork = "ts";
      };

      service."${name}-http" = rec {
        connect.sidecarService = {
          proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
            ];

            config = util.mkEnvoyProxyConfig {
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
        checks = [
          {
            expose = true;
            name = "metrics";
            port = "metrics";
            type = "http";
            path = meta.metrics_path;
            interval = 10 * time.second;
            timeout = 3 * time.second;
          }
        ];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
        ];
      };
      service."${name}-grpc" = {
        connect.sidecarService.proxy.config = util.mkEnvoyProxyConfig {
          otlpService = "proxy-${name}-grpc";
          otlpUpstreamPort = otlpPort;
          extra.local_request_timeout_ms = 5 * 60 * 1000;
          extra.protocol = "grpc";
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.grpc;
        # TODO gRPC health
        #      checks = [{
        #        expose = true;
        #        name = "metrics";
        #        portLabel = "metrics";
        #        type = "http";
        #        path = meta.metrics_path;
        #        interval = 10 * lib.seconds;
        #        timeout = 3 * lib.seconds;
        #      }];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.protocol=h2c"
          "traefik.http.routers.${name}-grpc.tls=true"
          "traefik.http.routers.${name}-grpc.entrypoints=web, websecure"
          "traefik.http.services.${name}-grpc.loadbalancer.server.scheme=h2c"
        ];
      };

      #      service."s-web-portfolio-http" = (import ./s-web-portfolio/consulService.nix) { inherit lib sidecarResources; };
      #      service."s-web-github-webhook-http" = (import ./s-web-github-webhook/consulService.nix) { inherit lib sidecarResources; };

      task.${name} = {
        inherit resources;
        driver = "docker";
        vault = { };

        config = {
          image = "ghcr.io/cottand/selfhosted/${name}:${version}";
        };
        env = {
          HTTP_HOST = "127.0.0.1";
          HTTP_PORT = toString ports.http;
          GRPC_PORT = toString ports.grpc;
          OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://localhost:${toString otlpPort}";
          OTEL_SERVICE_NAME = name;
          SELFHOSTED_SSL_ROOT_CA = "/local/root_ca.crt";
          DCOTTA_COM_VERSION = version;
        };
        templates = [
          {
            # db env
            env = true;
            data = ''
              {{with secret "secret/data/services/db-rw-default"}}
              CRDB_CONN_URL="postgres://{{.Data.data.username}}:{{.Data.data.password}}@localhost:${toString ports.upDb}/services?ssl_sni=roach-db.traefik"
              {{end}}
            '';
            destination = "secrets/.crdb";
            changeMode = "restart";
          }
          {
            destination = "local/root_ca.crt";
            data = ''
              {{- with secret "secret/data/nomad/infra/root_ca" -}}{{ .Data.data.value }}{{- end -}}
            '';
            changeMode = "restart";
          }
        ];

        vault.env = true;
        vault.role = "services-go";
        vault.changeMode = "restart";
        identities = [
          {
            name = "default";
            env = true;
            changeMode = "restart";
          }
        ];
      };
    };
  };
}
