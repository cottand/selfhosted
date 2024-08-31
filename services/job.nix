let
  lib = import ../jobs/lib;
  dbPort = 5432;
in
lib.mkServiceJob {
  name = "services-go";
  version = "ef470f3";
  upstream."roach-db".localBindPort = dbPort;
  cpu = 200;
  memMb = 200;
  ports.http = 8080;
  ports.grpc = 8081;
  httpTags = [
    "traefik.enable=true"
    "traefik.consulcatalog.connect=true"
    "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
    "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
  ];
  extraTaskConfig = {
    template."db-env" = {
      changeMode = "restart";
      envvars = true;
      embeddedTmpl = ''
        {{with secret "secret/data/services/db-rw-default"}}
        CRDB_CONN_URL="postgres://{{.Data.data.username}}:{{.Data.data.password}}@localhost:${toString dbPort}/services?ssl_sni=roach-db.traefik"
        {{end}}
      '';
    };
    vault.env = true;
    vault.role = "service-db-rw-default";
    vault.changeMode = "restart";
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
        #      sidecarTask.resources = sidecarResources;
      };
      port = "7001";
      tags = [ ];
    };
}
