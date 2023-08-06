{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./nomad/nomad.nix
    ./wg-easy.nix
    ./ipv6.nix
    # ./udp2raw.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "cosmo";
  networking.domain = "";
  services.openssh.enable = true;

  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  networking.firewall.enable = true;
  networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # 4647 4648 ];
    allowedTCPPorts = [ 22 ];
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


  system.stateVersion = "22.11";
}
