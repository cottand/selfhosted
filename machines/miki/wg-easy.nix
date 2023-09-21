{ config, pkgs, ... }: {
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers = {
    wg-easy = {
      # on 51820,51821
      image = "weejewel/wg-easy";
      autoStart = true;
      environment = {
        WG_HOST = "vpn.dcotta.eu";
        WG_PERSISTENT_KEEPALIVE = "25";
        WG_DEFAULT_ADDRESS = "10.2.0.x";
      };

      # volumes = [ "/root/secret/wg-easy:/etc/wireguard" ];
      extraOptions = [
        "--privileged"
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
      ];
    };
  };


  # deployment.keys."wg0.json" = {
  #   text = (builtins.readFile ../../secret/wg-easy/wg0.json);
  #   destDir = "/root/secret/wg-easy/";
  #   uploadAt = "pre-activation";
  # };

  # systemd.services.docker-wg-easy.partOf = [ "w0.json-key.service" ];

  networking = {
    firewall.trustedInterfaces = [ "wg0" ];
    firewall.allowedUDPPorts = [ 51820 ];
    nat = {
      enable = true;
      externalInterface = "eth0";
      internalInterfaces = [ "wg0" ];
    };
  };
}
