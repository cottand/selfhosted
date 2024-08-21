let
  lib = import ../../jobs/lib;
in
lib.mkServiceJob {
  upstream."s-portfolio-stats-grpc".localBindPort = 9083;
  name = "s-web-portfolio";
  version = "3489df4";
  cpu = 80;
  memMb = 200;
  ports.http = 8080;
}
