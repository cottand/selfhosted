{ util, time, defaults, ... }:
let
  lib = (import ../lib) { };
  version = "3.3";
  ports = {
    http-ui = 8080;
    http-ts = 8001;
    https-ts = 44301;
    http-public = 8000;
    https-public = 44300;
    sql = 5432;
    metrics = 3520;
    otlp = 9001;
  };
  resources = {
    cpu = 300;
    memory = 300;
    memoryMax = 500;
  };
  sidecarResources = util.mkResourcesWithFactor 0.10 resources;
in
{
  job."traefik" = {
    group."traefik" = {
      count = 3;
      constraints = [
        {
          attribute = "\${meta.box}";
          operator = "regexp";
          value = "(hez1|hez2|hez3)";
        }
        {
          operator = "distinct_hosts";
          value = "true";
        }
      ];
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."dns_ts".hostNetwork = "ts";
        port."http_ui".hostNetwork = "ts";
        reservedPorts = {
          "http_ts" = { static = 80; to = ports.http-ts; hostNetwork = "ts"; };
          "https_ts" = { static = 443; to = ports.https-ts; hostNetwork = "ts"; };
          "http_public" = { static = 80; to = ports.http-public; hostNetwork = "public"; };
          "https_public" = { static = 443; to = ports.https-public; hostNetwork = "public"; };
          # hardcoded so that prometheus can find it after restart
          "metrics" = { static = 3194; to = ports.metrics; hostNetwork = "ts"; };
          "sql" = { static = ports.sql; hostNetwork = "ts"; };
        };
      };
      service."traefik-metrics" = {
        port = toString ports.metrics;
        tags = [ "metrics" ];
        checks = [{
          name = "metrics";
          expose = true;
          port = "metrics";
          type = "http";
          path = "/metrics";
          interval = 10 * time.second;
          timeout = 3 * time.second;
        }];
        connect = {
          sidecarService = { };
          sidecarTask.resources = sidecarResources;
        };
        meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      };
      service."traefik" = {
        tags = [
          "traefik.enable=true"
          "traefik.http.routers.traefik_dash.entrypoints=web,websecure"
          "traefik.http.routers.traefik_dash.rule=Host(`traefik.tfk.nd`)"
          "traefik.http.routers.traefik_dash.tls=true"
          "traefik.http.routers.traefik_dash.service=api@internal"
        ];
        port = "http_ui";

        connect = {
          sidecarService.proxy.upstreams = [
            { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = ports.otlp; }
          ];
          sidecarTask.resources = sidecarResources;
        };
      };
      service."traefik-ingress" = {
        port = "http_ts";
        task = "traefik";
        connect.native = true;
      };
      task."traefik" = {
        vault = { };
        driver = "docker";
        config = {
          image = "traefik:${version}";
          volumes = [
            "local/traefik.toml:/etc/traefik/traefik.toml"
            "local/traefik-dynamic.toml:/etc/traefik/dynamic/traefik-dynamic.toml"
          ];
        };
        templates = [
          {
            destination = "local/traefik-dynamic.toml";
            data = builtins.readFile ./dynamic.toml;
            changeMode = "signal";
          }
          {
            destination = "local/traefik.toml";
            changeMode = "restart";
            data = builtins.readFile ./static.toml;
          }
          {
            destination = "secrets/internal_cert/cert";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/traefik/internal-cert"}}
              {{.Data.data.chain}}
              {{end}}
            '';
          }
          {
            destination = "secrets/internal_cert/key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/traefik/internal-cert"}}
              {{.Data.data.key}}
              {{end}}
            '';
          }
        ];
        identities = [{ }];
        inherit resources;
      };
    };
  };
}
