{ config, pkgs, ... }: {
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers = {
    wg-easy = {
      image = "weejewel/wg-easy";
      autoStart = true;
      environment = {
        WG_HOST = "185.216.203.147";
        WG_PERSISTENT_KEEPALIVE = "25";
        WG_DEFAULT_ADDRESS = "10.8.0.x";
      };

      volumes = [ "/root/secret/wg-easy:/etc/wireguard" ];
      extraOptions = [
        "--privileged"
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
      ];
    };
  };


  deployment.keys."wg0.json" = {
    text = (builtins.readFile ../../secret/wg-easy/wg0.json);
    destDir = "/root/secret/wg-easy/";
    uploadAt = "pre-activation";
  };

  systemd.services.docker-wg-easy.partOf = [ "w0.json-key.service" ];
}
