{ pkgs, ... }: {
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
  };
  services.nomad.settings = {
    datacenter = "london-home";
  };


  system.stateVersion = "22.11";
}
