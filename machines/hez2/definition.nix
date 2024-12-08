{ name, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.domain = "";
  services.openssh.enable = true;


  nomadNode = {
    enable = true;
    extraSettingsText = ''
      datacenter = "nuremberg-hetzner"
      client {
        host_network "public" {
          interface           = "eth0"
          reserved_ports      = "22"
        }
        host_network "local-hetzner" {
          interface           = "enp7s0"
          reserved_ports      = "22"
        }
      }
    '';
    enableSeaweedFsVolume = false;
    hostVolumes."roach" = {
      hostPath = "/roach.d";
      readOnly = false;
    };
  };
  services.nomad.settings = {
    client.meta.controlPlane = "true";
  };

  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.11";
}
