{ util, time, defaults, ... }:
let
  version = "11.3.2";
  cpu = 100;
  mem = 240;
  ports = {
    http = 8888;
    upDb = 5432;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = "127.0.0.1";
in
{
  job."grafana" = {
    type = "service";
    affinities = [{
      attribute = "\${meta.controlPlane}";
      operator = "is";
      value = "true";
      weight = -80;
    }];
    group."grafana" = {
      count = 2;
      network = {
        inherit (defaults) dns;
        mode = "bridge";

        port."healthz".hostNetwork = "ts";
      };

      restart = {
        attempts = 4;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };
      update = {
        maxParallel = 1;
        canary = 1;
        minHealthyTime = 30 * time.second;
        healthyDeadline = 5 * time.minute;
        autoRevert = true;
        autoPromote = true;
      };

      service."grafana" = {
        port = "3000";
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "roach-db"; localBindPort = ports.upDb; }
              { destinationName = "mimir-http"; localBindPort = 8000; }
              { destinationName = "tempo-http"; localBindPort = 8001; }
              { destinationName = "loki-http"; localBindPort = 8002; }
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-grafana-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };

          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          name = "healthz";
          expose = true;
          port = "healthz";
          type = "http";
          path = "/api/health";
          interval = 20 * time.second;
          timeout = 5 * time.second;
          checkRestart = {
            limit = 3;
            grace = 30 * time.second;
            ignoreWarnings = false;
          };
          task = "grafana";
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.middlewares=vpn-whitelist@file"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
          "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
        ];

      };
      task."grafana" = {
        vault.env = true;
        driver = "docker";
        config = {
          image = "grafana/grafana:${version}";
          ports = [ "http" ];
          args = [ "--config" "/local/config.ini" ];
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);
        };
        user = "root:root";
        env = builtins.mapAttrs (_: toString) {
          "GF_AUTH_BASIC_ENABLED" = false;
          "GF_AUTH_DISABLE_LOGIN_FORM" = false;
          "GF_AUTH_ANONYMOUS_ENABLED" = true;
          "GF_AUTH_ANONYMOUS_ORG_ROLE" = "Viewer";
          "GF_SERVER_ROOT_URL" = "https://grafana.traefik";
          "GF_SERVER_SERVE_FROM_SUB_PATH" = true;
          "GF_SECURITY_ALLOW_EMBEDDING" = true;
          "GF_FEATURE_TOGGLES_ENABLE" = "traceToMetrics logsExploreTableVisualisation";
          GF_INSTALL_PLUGINS = "https://storage.googleapis.com/integration-artifacts/grafana-lokiexplore-app/grafana-lokiexplore-app-latest.zip;grafana-lokiexplore-app, oci-metrics-datasource";
        };

        templates = [
          {
            destination = "local/config.ini";
            changeMode = "restart";
            data = ''
              [database]
                type = "postgres"
                host = "${bind}:${toString ports.upDb}"
                user = "grafana"
                ssl_mode = "verify-ca"
                ssl_sni = "roach-db.tfk.nd"
                server_cert_name = "roach-db.tfk.nd"
                ca_cert_path = "/secrets/ca.crt"
                client_key_path = "/secrets/client.grafana.key"
                client_cert_path = "/secrets/client.grafana.crt"
            '';
          }
          {
            destination = "/secrets/client.grafana.key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.key}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/client.grafana.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.chain}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/ca.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.ca}}{{end}}
            '';
            perms = "0600";
          }
        ];
      };
    };
  };
}
