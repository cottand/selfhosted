{ pkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    ./nomad/nomad.nix
    ./ipv6.nix
  ];

  networking.hostName = "cosmo";
  networking.domain = "";

  networking.firewall.enable = true;
  networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # 4647 4648 ];
#    allowedTCPPorts = [ 22 ];
  };
  # allow all from VPN
  networking.firewall.trustedInterfaces = [ "wg0" "nomad" "docker0" ];
  # virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;
  networking.nat = {
    enable = true;
    externalInterface = "ens18";
    internalInterfaces = [ "wg0" ];
  };

  system.stateVersion = "23.11";
}
