{ name, pkgs, ... }: {
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

  # turn screen off 10s after startup
  systemd.services.imac-screen-off = {
    environment."TERM" = "linux";
    script = ''
      ${pkgs.util-linux}/bin/setterm --blank poke </dev/tty1
      sleep 1
      ${pkgs.util-linux}/bin/setterm --blank force </dev/tty1
    '';
    #    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
  };


  ## Nomad
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
  };
  services.nomad.settings = {
    datacenter = "london-home";
  };
  services.tailscale = {
    extraSetFlags = ["--advertise-exit-node"];
  };
  boot.kernel.sysctl."net.ipv4.ip_forward" = "1";

  system.stateVersion = "25.05";
}
