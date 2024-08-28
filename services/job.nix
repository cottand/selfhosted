let
  lib = import ../jobs/lib;
  dbPort = 5432;
in
lib.mkServiceJob {
  name = "services";
  version = "e2f365f";
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
}
