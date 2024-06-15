{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./nomad.nix
    ./wg-easy.nix
    ./ipv6.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "miki";
  networking.domain = "";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ7FM2wEuWoUuxRkWnP6PNEtG+HOcwcZIt6Qg/Y1jhk''
  ];


  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  networking.firewall.enable = true;
  networking.firewall = {
    # WG whitelisted in lib/make-wireguard
    allowedTCPPorts = [ 22 ];
    # for wg-ui VPN
    allowedUDPPorts = [ 51825 ];
  };

  networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.11";
}
