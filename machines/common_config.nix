{ config, pkgs, lib, ... }:
{
  nixpkgs.config.allowUnfree = true;
  services.openssh.enable = true;
  services.sshguard.enable = true;
  networking.enableIPv6 = true;
  # Enable zsh
  programs.zsh.enable = true;

  # Enable Oh-my-zsh
  programs.zsh.ohMyZsh = {
    enable = true;
    theme = "fishy";
    plugins = [ "git" "sudo" "docker" "systemadmin" ];
  };

  users.users."cottand".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGes99PbsDcHDl3Jwg4GYqYRkzd6tZPH4WX4/ThP//BN"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ7FM2wEuWoUuxRkWnP6PNEtG+HOcwcZIt6Qg/Y1jhk nico.dc@outlook.com"
    # content of authorized_keys file
    # note: ssh-copy-id will add user@clientmachine after the public key
    # but we can remove the "@clientmachine" part
  ];

  users.users.root.shell = pkgs.zsh;

  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ7FM2wEuWoUuxRkWnP6PNEtG+HOcwcZIt6Qg/Y1jhk nico.dc@outlook.com" ];


  environment.systemPackages = with pkgs; [
    wireguard-tools
    python3 # required for sshuttle
    seaweedfs # makes 'weed' bin available
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
  time.timeZone = lib.mkDefault "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Configure keymap in X11
  services.xserver = {
    layout = "gb";
    xkbVariant = "";
  };

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
      expat
      # ...
    ];
  };
}
