{ config, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nomad.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "elvis";
  networking.networkmanager.enable = true;


  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    # usbutils
    # pciutils
    iw
    zsh
  ];


  networking.firewall.enable = true;
  networking.firewall.package = pkgs.iptables;
  #networking.firewall.allowedUDPPorts = [ 51820 4647 4648 ];

  system.stateVersion = "22.11";
}
