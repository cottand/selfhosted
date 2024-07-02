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
      }
    '';
    enableSeaweedFsVolume = false;
    hostVolumes."roach" = {
      hostPath = "/roach.d";
      readOnly = false;
    };
  };

  consulNode.server = true;

  system.stateVersion = "23.11";
}
