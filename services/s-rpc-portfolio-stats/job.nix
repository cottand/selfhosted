let
  lib = import ../../jobs/lib;
in
lib.mkServiceJob {
  upstream = {};
  name = "s-rpc-portfolio-stats";
  version = "37242c1";
  cpu = 80;
  memMb = 200;
  ports.http = 8080;
  ports.grpc = 8081;
}
