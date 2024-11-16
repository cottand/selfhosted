{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./wireguard.nix
      ./nomad/nomad.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  users.users.cottand.extraGroups = [ "networkmanager"  ];

  networking.firewall.enable = false;
  services.logind.lidSwitch = "ignore";

  system.stateVersion = "22.11";
}
