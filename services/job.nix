let
  lib = import ../jobs/lib;
  name = "services-go";
  version = "86358d4";
  cpu = 120;
  mem = 500;
  ports = {
    http = 8080;
    grpc = 8081;
    upDb = 5432;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memoryMB = 0.25 * mem;
    memoryMaxMB = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
lib.mkJob name {
  affinities = [{
    lTarget = "\${meta.controlPlane}";
    operand = "=";
    rTarget = "true";
    weight = -50;
  }];
  update = {
    maxParallel = 1;
    autoRevert = true;
    autoPromote = true;
    canary = 1;
  };

  group.${name} = {
    count = 1;
    network = {
      mode = "bridge";
      dynamicPorts = [
        { label = "metrics"; }
      ];
      reservedPorts = [
      ];
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

    # first declare here then import from each service's subfolder!
    service."s-web-portfolio-http" =
      let
        name = "s-web-portfolio";
      in
      {
        connect = {
          sidecarService.proxy = {
            config = lib.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-http";
              otlpUpstreamPort = 9001;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };
        port = "7001";
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}.tls=true"
          "traefik.http.routers.${name}.entrypoints=web, websecure"
        ];
      };
    task.${name} = {
      driver = "docker";
      vault = { };

      config = {
        image = "ghcr.io/cottand/selfhosted/${name}:${version}";
      };
      env = {
        HTTP_HOST = lib.localhost;
        HTTP_PORT = toString ports.http;
        GRPC_PORT = toString ports.grpc;
      };
      resources = {
        cpu = cpu;
        memoryMb = mem;
        memoryMaxMb = builtins.ceil (2 * mem);
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
      vault.env = true;
      vault.role = "service-db-rw-default";
      vault.changeMode = "restart";
    };
  };
}
