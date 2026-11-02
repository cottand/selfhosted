{ util, time, defaults, ... }:
let
  version = "3.7";
  ports = {
    http-ui = 8080;
    http-ts = 8001;
    # exposed in tailscale for node + in tailscale as service via sidecar
    https-ts = 44301;
    http-public = 8000;
    https-public = 44300;
    sql = 5432;
    metrics = 3520;
    otlp = 9001;
    cloudflared = 8888;
    cloudflared_metrics = 2000;
  };
  resources = {
    cpu = 550;
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
        port = {
          "http_ts" = { static = 80; to = ports.http-ts; hostNetwork = "ts"; };
          "https_ts" = { static = 443; to = ports.https-ts; hostNetwork = "ts"; };
          "http_public" = { static = 80; to = ports.http-public; hostNetwork = "public"; };
          "https_public" = { static = 443; to = ports.https-public; hostNetwork = "public"; };
          # hardcoded so that prometheus can find it after restart
          "metrics" = { static = 3194; to = ports.metrics; hostNetwork = "ts"; };
          "cloudflared_metrics" = { static = 3195; to = ports.cloudflared_metrics; hostNetwork = "ts"; };
          "sql" = { static = ports.sql; hostNetwork = "ts"; };
        };
      };
      service."traefik-metrics" = {
        port = toString ports.metrics;
        tags = [ "metrics" ];
        checks = [
          #        {
          #          name = "metrics";
          #          expose = true;
          #          port = "metrics";
          #          type = "http";
          #          path = "/metrics";
          #          interval = 10 * time.second;
          #          timeout = 3 * time.second;
          #        }
        ];
        connect = {
          sidecarService = { };
          sidecarTask.resources = sidecarResources;
        };
        meta.metrics_port = "\${NOMAD_HOST_PORT_metrics}";
      };
      service."traefik-cloudflared-metrics" = {
        port = toString ports.cloudflared_metrics;
        tags = [ "metrics" ];
        checks = [
          {
            name = "cf-metrics";
            expose = true;
            port = "cloudflared_metrics";
            type = "http";
            path = "/metrics";
            interval = 10 * time.second;
            timeout = 3 * time.second;
          }
        ];
        connect = {
          sidecarService = { };
          sidecarTask.resources = sidecarResources;
        };
        meta.metrics_port = "\${NOMAD_HOST_PORT_cloudflared_metrics}";
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
      task."tailscale-service-traefik" = {
        lifecycle = {
          hook = "poststart";
          sidecar = true;
        };
        vault = { };
        driver = "docker";
        config = {
          image = "tailscale/tailscale:stable";
          entrypoint = [ "/bin/sh" "-c" ];
          # serve fails until the node has logged in, and containerboot must stay PID 1 to unadvertise on SIGTERM
          args = [
            ''
              until tailscale --socket="$TS_SOCKET" serve --service=svc:traefik --tcp=443 --yes tcp://127.0.0.1:${toString ports.https-ts}; do
                sleep 2
              done &
              exec /usr/local/bin/containerboot
            ''
          ];
        };
        env = {
          TS_HOSTNAME = "traefik-\${NOMAD_ALLOC_INDEX}";
          TS_STATE_DIR = "/secrets/tailscale";
          TS_AUTH_ONCE = "true";
          TS_SOCKET = "/tmp/tailscaled.sock";
        };
        templates = [{
          destination = "secrets/tailscale.env";
          changeMode = "restart";
          env = true;
          data = ''
            {{ with secret "secret/data/nomad/job/traefik/tailscale" }}
            TS_AUTHKEY={{ .Data.data.authkey }}
            {{ end }}
          '';
        }];
        resources = {
          cpu = 100;
          memory = 100;
          memoryMax = 500;
        };
      };
      task."cloudflared-traefik" = {
        lifecycle = {
          hook = "poststart";
          sidecar = true;
        };
        driver = "docker";
        vault = { };
        config = {
          image = "cloudflare/cloudflared:2026.8.2";
          args = [
            "tunnel"
            "--no-autoupdate"
            "--metrics"
            "0.0.0.0:${toString ports.cloudflared_metrics}"
            "run"
          ];
        };
        resources = {
          cpu = 100;
          memory = 128;
          memoryMax = 256;
        };
        templates = [{
          destination = "secrets/cloudflared.env";
          changeMode = "restart";
          env = true;
          data = ''
            {{ with secret "secret/data/nomad/job/traefik/cloudflared" }}
            TUNNEL_TOKEN={{ .Data.data.token }}
            {{ end }}
          '';
        }];
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
        identities = [{
          env = true;
        }];
        inherit resources;
      };
    };
  };
}
