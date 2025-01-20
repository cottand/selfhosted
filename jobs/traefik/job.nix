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
    memoryMB = 300;
    memoryMaxMB = 500;
  };
  sidecarResources = lib.mkResourcesWithFactor 0.10 resources;
in
lib.mkJob "traefik" {
  group."traefik" = {
    count = 3;
    constraints = [
      {
        lTarget = "\${meta.box}";
        operand = "regexp";
        rTarget = "(hez1|hez2|hez3)";
      }
      {
        operand = "distinct_hosts";
        rTarget = "true";
      }
    ];
    network = {
      inherit (lib.defaults) dns;
      mode = "bridge";
      dynamicPorts = [
        { label = "dns_ts"; hostNetwork = "ts"; }
        { label = "http_ui"; hostNetwork = "ts"; }
      ];
      reservedPorts = [
        { label = "http_ts"; to = ports.http-ts; value = 80; hostNetwork = "ts"; }
        { label = "https_ts"; to = ports.https-ts; value = 443; hostNetwork = "ts"; }
        { label = "http_public"; to = ports.http-public; value = 80; hostNetwork = "public"; }
        { label = "https_public"; to = ports.https-public; value = 443; hostNetwork = "public"; }
        { label = "sql"; value = ports.sql; hostNetwork = "ts"; }
        # hardcoded so that prometheus can find it after restart
        { label = "metrics"; value = 3194; to = ports.metrics; hostNetwork = "ts"; }
      ];
    };
    volumes."ca-certificates" = rec {
      name = "ca-certificates";
      type = "host";
      readOnly = true;
      source = name;
    };
    service. "traefik-metrics" = {
      port = ports.metrics;
      tags = [ "metrics" ];
      check."metrics" = {
        expose = true;
        port = "metrics";
        type = "http";
        path = "/metrics";
        interval = 10 * lib.seconds;
        timeout = 3 * lib.seconds;
      };
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
      #      // check {
      #      //   name     = "alive"
      #      //   type     = "tcp"
      #      //   interval = "20s"
      #      //   timeout  = "2s"
      #      // }

      connect = {
        sidecarService.proxy.upstream."tempo-otlp-grpc-mesh".localBindPort = ports.otlp;
        sidecarTask.resources = sidecarResources;
      };
    };
    service."traefik-ingress" = {
      port = "http_ts";
      taskName = "traefik";
      connect.native = true;
    };
    task."traefik" = {
      vault = { };
      driver = "docker";
      volumeMounts = [{
        volume = "ca-certificates";
        destination = "/etc/ssl/certs";
        readOnly = true;
        propagationMode = "host-to-task";
      }];
      config = {
        image = "traefik:${version}";
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml"
          "local/traefik-dynamic.toml:/etc/traefik/dynamic/traefik-dynamic.toml"
        ];
      };
      template."local/traefik-dynamic.toml" = {
        embeddedTmpl = builtins.readFile ./dynamic.toml;
        changeMode = "signal";
      };

      template. "local/traefik.toml" = {
        changeMode = "restart";
        embeddedTmpl = builtins.readFile ./static.toml;
      };
      template."secrets/internal_cert/cert" = {
        changeMode = "restart";
        embeddedTmpl = ''
          {{with secret "secret/data/nomad/job/traefik/internal-cert"}}
          {{.Data.data.chain}}
          {{end}}
        '';
      };
      template."secrets/internal_cert/key" = {
        changeMode = "restart";
        embeddedTmpl = ''
          {{with secret "secret/data/nomad/job/traefik/internal-cert"}}
          {{.Data.data.key}}
          {{end}}
        '';
      };
      identity.env = true;
      inherit resources;
    };
  };
}
