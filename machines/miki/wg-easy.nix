{ config, pkgs, ... }: {
  virtualisation.oci-containers.backend = "docker";
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
