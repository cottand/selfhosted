let
  lib = import ../../jobs/lib;
in
lib.mkServiceJob {
  name = "mono";
  version = "713a6bc";
  cpu = 80;
  memMb = 200;
  ports.http = 8080;
  ports.grpc = 8081;
  httpTags = [
    "traefik.enable=true"
    "traefik.consulcatalog.connect=true"
    "traefik.http.routers.\${NOMAD_GROUP_NAME}.tls=true"
    "traefik.http.routers.\${NOMAD_GROUP_NAME}.entrypoints=web, websecure"
  ];
}
