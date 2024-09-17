let
  lib = (import ./lib) { };
  otlpPort = 9001;
in
lib.mkJob "debug" {
  group."debug" = {

    network = {
      mode = "bridge";
      port."web" = {
        to = 80;
        hostNetwork = "ts";
      };
    };

    service."debug" = {
      port = "web";
      connect.sidecarService.proxy = {
        upstreams = [
          {
            destinationName = "roach-web";
            localBindPort = 8001;
          }
          {
            destinationName = "whoami";
            localBindPort = 8002;
          }
          {
            destinationName = "web-portfolio-c";
            localBindPort = 8003;
          }
          {
            destinationName = "tempo-otlp-grpc-mesh";
            localBindPort = otlpPort;
          }
        ];
        config = lib.mkEnvoyProxyConfig {
          otlpService = "proxy-debug";
          otlpUpstreamPort = otlpPort;
        };
      };
    };
    task."debug" = {
      driver = "docker";

      config = {
        image = "nixos/nix";
        command = "bash";
        ports = [ "http" ];
        args = [
          "-c"
          "sleep 1000000"
        ];
      };
    };
  };
}
