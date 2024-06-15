{ pkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    ./nomad/nomad.nix
    ./ipv6.nix
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

  custom.wireguard."wg-gha-ci" = {
    enable = true;
    confPath = ../../secret/wg-ci/wg-ci.conf;
    port = 55726;
  };


  system.stateVersion = "23.11";
}
