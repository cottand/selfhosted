let
  lib = import ../../jobs/lib;

  dbPort = 5432;
in
lib.mkServiceJob {
  name = "s-rpc-portfolio-stats";
  version = "b817c02";
  upstream."roach-db".localBindPort = dbPort;
  cpu = 80;
  memMb = 200;
  ports.http = 8080;
  ports.grpc = 8081;

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
