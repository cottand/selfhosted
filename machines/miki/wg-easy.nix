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
        WG_DEFAULT_DNS = "10.2.0.1";
      };

      volumes = [ "/mnt/weed/buckets/vpn-de/:/etc/wireguard" ];
      extraOptions = [
        "--privileged"
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
      ];
    };
  };


  systemd.services.weed_mount = {
    enable = true;
    description = "Mount weed fs";
    # preStart = "mkdir -p /mnt/weed";
    serviceConfig = {
      ExecStart = "${pkgs.seaweedfs}/bin/weed mount -filer=10.10.0.1:8888 -dir=/mnt/weed";
    };
    before = [ "docker-wg-easy.service" ];
    wantedBy = [ "docker-wg-easy.service" ];
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
