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
      server {
        enabled          = true
        bootstrap_expect = 3
        server_join {
          retry_join = [
            "hez2.mesh.dcotta.eu",
            "hez3.mesh.dcotta.eu",
          ]
          retry_max      = 3
          retry_interval = "15s"
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
  networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.11";
}
