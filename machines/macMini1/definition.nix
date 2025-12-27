{ pkgs, lib, ... }:
let
  usbPlugin = builtins.fetchurl {
    url = "https://gitlab.com/api/v4/projects/23395095/packages/generic/nomad-usb-device-plugin/0.4.0/nomad-usb-device-plugin-linux-amd64-0.4.0";
    sha256 = "sha256:1vhw1754rmhvj98g56m3d2kb9l2agns5558jhic7c6k7i8qzcvf4";
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.tmp.cleanOnBoot = true;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";


  networking.networkmanager.enable = true;

  zramSwap.enable = true;

  services.openssh.enable = true;

  users.users.cottand = {
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
  };

  networking.firewall.enable = true;
  networking.firewall = {
    allowedTCPPorts = [ 22 ];
  };

  services.logind.lidSwitch = "ignore";

  networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;


  ## Nomad
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    hostVolumes."motioneye" = {
      hostPath = "/motioneye.d";
      readOnly = false;
    };
  };
  services.nomad.extraSettingsPlugins = [ ./plugins ];

  services.nomad.extraPackages = [ pkgs.libusb1 ];
  services.nomad.settings = {
    datacenter = "london-home";
    plugin."usb" = {
      enabled = true;
      included_vendor_ids = [ ];
      excluded_vendor_ids = [ ];

      included_product_ids = [ ];
      excluded_product_ids = [ ];
    };
  };
  programs.nix-ld = {
    enable = true;
    libraries = [ pkgs.libusb1 ];
  };


  system.stateVersion = "22.11";
}
