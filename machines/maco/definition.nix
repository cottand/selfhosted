{ config, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./ipv6.nix
      ./nomad.nix
    ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "maco";

  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    usbutils
    pciutils
    iw
  ];
  #networking.firewall.allowedUDPPorts = [ 51820 4647 4648 ];
  networking.firewall.enable = true;
  networking.firewall = {
    # WG whitelisted in lib/make-wireguard
    allowedTCPPorts = [ 22 ];
    # for wg-ui VPN
    allowedUDPPorts = [ 51825 ];
  };

  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.05";
}
