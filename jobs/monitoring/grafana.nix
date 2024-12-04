let
  lib = (import ../lib) { };
  version = "11.3.2";
  cpu = 100;
  mem = 240;
  ports = {
    http = 8888;
    upDb = 5432;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
  bind = lib.localhost;
in
lib.mkJob "grafana" {
  type = "service";
  group."grafana" = {
    affinities = [{
      lTarget = "\${meta.controlPlane}";
      operand = "=";
      rTarget = "true";
      weight = -80;
    }];
    count = 2;
    network = {
      inherit (lib.defaults) dns;
      mode = "bridge";
      dynamicPorts = [
        { label = "healthz"; hostNetwork = "ts"; }
      ];
    };

    restartPolicy = {
      attempts = 4;
      interval = 10 * lib.minutes;
      delay = 15 * lib.seconds;
      mode = "delay";
    };
    update = {
      maxParallel = 1;
      canary = 1;
      minHealthyTime = 30 * lib.seconds;
      healthyDeadline = 5 * lib.minutes;
      autoRevert = true;
      autoPromote = true;
    };

    service."grafana" = {
      port = "3000";
      connect = {
        sidecarService.proxy = {
          upstream = {
            "roach-db".localBindPort = ports.upDb;
            "mimir-http".localBindPort = 8000;
            "tempo-http".localBindPort = 8001;
            "loki-http".localBindPort = 8002;
            "tempo-otlp-grpc-mesh".localBindPort = otlpPort;
          };
          config = lib.mkEnvoyProxyConfig {
            otlpService = "proxy-grafana-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };

        sidecarTask.resources = sidecarResources;
      };

      check."healthz" = {
        expose = true;
        port = "healthz";
        type = "http";
        path = "/api/health";
        interval = 20 * lib.seconds;
        timeout = 5 * lib.seconds;
        checkRestart = {
          limit = 3;
          grace = 30 * lib.seconds;
          ignoreWarnings = false;
        };
        task = "grafana";
      };

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
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
      };
      user = "root:root";
      env = builtins.mapAttrs (_: toString) {
        "GF_AUTH_BASIC_ENABLED" = false;
        "GF_AUTH_DISABLE_LOGIN_FORM" = false;
        "GF_AUTH_ANONYMOUS_ENABLED" = true;
        "GF_AUTH_ANONYMOUS_ORG_ROLE" = "Viewer";
        "GF_SERVER_ROOT_URL" = "http://grafana.traefik";
        "GF_SERVER_SERVE_FROM_SUB_PATH" = true;
        "GF_SECURITY_ALLOW_EMBEDDING" = true;
        "GF_FEATURE_TOGGLES_ENABLE" = "traceToMetrics logsExploreTableVisualisation";
        GF_INSTALL_PLUGINS = "https://storage.googleapis.com/integration-artifacts/grafana-lokiexplore-app/grafana-lokiexplore-app-latest.zip;grafana-lokiexplore-app, oci-metrics-datasource";
      };

      template."local/config.ini" = {
        changeMode = "restart";

        embeddedTmpl = ''
          [database]
            type = "postgres"
            host = "${bind}:${toString ports.upDb}"
            user = "grafana"
            ssl_mode = "verify-ca"
            ssl_sni = "roach-db.tfk.nd"
            servert_cert_name = "roach-db.tfk.nd"
            ca_cert_path = "/secrets/ca.crt"
            client_key_path = "/secrets/client.grafana.key"
            client_cert_path = "/secrets/client.grafana.crt"
        '';
      };
      template."/secrets/client.grafana.key" = {
        changeMode = "restart";
        embeddedTmpl = ''
          {{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.key}}{{end}}
        '';
        perms = "0600";
      };
      template."/secrets/client.grafana.crt" = {
        changeMode = "restart";
        embeddedTmpl = ''
          {{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.chain}}{{end}}
        '';
        perms = "0600";
      };
      template."/secrets/ca.crt" = {
        changeMode = "restart";
        embeddedTmpl = ''
          {{with secret "secret/data/nomad/job/roach/users/grafana"}}{{.Data.data.ca}}{{end}}
        '';
        perms = "0600";
      };
    };
  };
}
