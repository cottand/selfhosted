{ config, pkgs, ... }: {
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nomad/nomad.nix
      ./wireguard.nix
    ];
  deployment.tags = [ "ari" ];



  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.extraModulePackages = with config.boot.kernelPackages; [ rtl88xxau-aircrack ];
  # boot.kernelModules = [];

  networking.hostName = "ari"; # Define your hostname.
  #networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;


  # Define a user account. Don't forget to set a password with ‘passwd’.
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
    iptables
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    # busybox
    usbutils
    pciutils
    iw
    zsh
    pkgs.linuxKernel.packages.linux_5_15.rtl88xxau-aircrack
    pkgs.nomad
  ];

  # List services that you want to enable
  # Enable the OpenSSH daemon.
  #networking.firewall.allowedTCPPorts = [ 4646 22 4647 4648];


  # Open ports in the firewall.
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  networking.firewall.package = pkgs.iptables;
  #networking.firewall.allowedUDPPorts = [ 51820 4647 4648 ];

  system.stateVersion = "22.11";

}
