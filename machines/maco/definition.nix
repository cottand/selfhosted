{ config, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # ./wireguard.nix
      ./nomad/nomad.nix
      ./ipv6.nix
    ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  # Bootloader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "maco";
  # networking.networkmanager.enable = true;

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

  networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.05";
}
