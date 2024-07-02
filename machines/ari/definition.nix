{ pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./nomad.nix
  ];

  boot.tmp.cleanOnBoot = true;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  zramSwap.enable = true;

  services.openssh.enable = true;

  users.users.cottand = {
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
  };

  networking.firewall.enable = true;
  networking.firewall = {
    # WG whitelisted in lib/make-wireguard
    allowedTCPPorts = [ 22 ];
  };
  
  services.logind.lidSwitch = "ignore";

  networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.05";
}
