{ pkgs, config, lib, flakeInputs, ... }:
{

  security.pki.certificateFiles = [
    flakeInputs.self.rootCa
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
    gc.automatic = true;
    gc.options = "--delete-older-than 15d";
    gc.dates = "daily";
    optimise.automatic = true;
    settings = {
      auto-optimise-store = true;
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "@wheel" ];
    };
  };

  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  users.users.nico = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    hashedPasswordFile = "";
  };

  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 1 * 1024;
  }];

  services.openssh.enable = true;
  services.openssh.openFirewall = false;
  services.openssh.settings.PasswordAuthentication = false;
  services.sshguard.enable = true;

  users.users."cottand".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGes99PbsDcHDl3Jwg4GYqYRkzd6tZPH4WX4/ThP//BN"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ7FM2wEuWoUuxRkWnP6PNEtG+HOcwcZIt6Qg/Y1jhk nico.dc@outlook.com"
    # nico-xps key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF3AKGuE56RZiMURZ4ygV/BrSwrq6Ozp46VVm30PouPQ"
  ];

  programs.fish.enable = true;
  users.users.root.shell = pkgs.fish;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ7FM2wEuWoUuxRkWnP6PNEtG+HOcwcZIt6Qg/Y1jhk nico.dc@outlook.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF3AKGuE56RZiMURZ4ygV/BrSwrq6Ozp46VVm30PouPQ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt nico.dc@outlook.com-m3"
  ];

  environment.systemPackages = with pkgs; [
    #python3 # required for sshuttle
    pciutils # for setpci, lspci
    dig
    iw
    vim
    htop
    s-tui # power top
    nmap
    traceroute
  ];

  # Set your time zone.
  time.timeZone = "UTC";

  networking = {
    enableIPv6 = true; # oci nodes do not have IPv6
    timeServers = [ "time.google.com" ];
    firewall.checkReversePath = false;
  };
  services.chrony.enable = true;


  # Select internationalisation properties.
  #  i18n.defaultLocale = "en_GB.UTF-8";

  #  i18n.extraLocaleSettings = {
  #    LC_ADDRESS = "en_GB.UTF-8";
  #    LC_IDENTIFICATION = "en_GB.UTF-8";
  #    LC_MEASUREMENT = "en_GB.UTF-8";
  #    LC_MONETARY = "en_GB.UTF-8";
  #    LC_NAME = "en_GB.UTF-8";
  #    LC_NUMERIC = "en_GB.UTF-8";
  #    LC_PAPER = "en_GB.UTF-8";
  #    LC_TELEPHONE = "en_GB.UTF-8";
  #    LC_TIME = "en_GB.UTF-8";
  #  };

  # Configure console keymap
  console.keyMap = "uk";

  # see https://blog.thalheim.io/2022/12/31/nix-ld-a-clean-solution-for-issues-with-pre-compiled-executables-on-nixos/
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      fuse3
      icu
      zlib
      nss
      openssl
      curl
      wget
      expat
    ];
  };
}
