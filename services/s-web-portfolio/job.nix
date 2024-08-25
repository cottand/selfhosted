let
  lib = import ../../jobs/lib;
in
lib.mkServiceJob {
  upstream."s-rpc-portfolio-stats-grpc".localBindPort = 9083;
  name = "s-web-portfolio";
  version = "c228e50";
  cpu = 80;
  memMb = 200;
  ports.http = 8080;
  httpTags = [
    "traefik.enable=true"
    "traefik.consulcatalog.connect=true"
    "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
    "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
  ];
}
