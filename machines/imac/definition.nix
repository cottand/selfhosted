{ name, ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.tmp.cleanOnBoot = true;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  zramSwap.enable = true;

  services.openssh.enable = true;

  networking.firewall.enable = true;
  networking.firewall = {
    allowedTCPPorts = [ 22 ];
  };

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

  system.stateVersion = "25.05";
}
