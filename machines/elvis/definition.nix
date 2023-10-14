{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nomad/nomad.nix
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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

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
