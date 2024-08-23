let
  lib = import ../../jobs/lib;
in
lib.mkServiceJob {
  upstream = {};
  name = "s-portfolio-stats";
  version = "c228e50";
  cpu = 80;
  memMb = 200;
  ports.http = 8080;
  ports.grpc = 8081;
}
