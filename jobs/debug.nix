{
  job."debug" = {
    group."debug" = {
      constraints = [{
        attribute = "\${meta.box}";
        operator = "=";
        value = "hez3";
      }];

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
          ];
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
  };
}
