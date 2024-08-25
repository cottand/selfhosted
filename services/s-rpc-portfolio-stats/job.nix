let
  lib = import ../../jobs/lib;

  dbPort = 5432;
in
lib.mkServiceJob {
  name = "s-rpc-portfolio-stats";
  version = "1652149";
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
        {{with secret "secret/data/nomad/job/roach/users/grafana"}}
        CRDB_CONN_URL="postgres://{{.Data.data.username}}:{{.Data.data.password}}@localhost:${toString dbPort}?ssl_sni=roach-db.traefik"
        {{end}}
      '';
    };
    identities = [{
      audience = [ "vault.io" ];
      changeMode = "restart";
      name = "service-db-rw-default";
      TTL = 3600 * lib.seconds;
    }];
  };
}
