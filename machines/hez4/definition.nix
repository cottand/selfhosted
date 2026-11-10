{ name, pkgs, modulesPath, flakeInputs, ... }: {
  # based on https://github.com/nix-community/nixos-anywhere-examples/blob/main/configuration.nix
  imports = [
    ./hardware-configuration.nix
    #./networking.nix # generated at runtime by nixos-infect
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")

    ./disk.nix

    (flakeInputs.disko.nixosModules.disko)
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.domain = "";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [ ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcVLH2EH/aAkul8rNWrDoBTjUTL3Y+6vvlVw5FSh8Gt nico.dc@outlook.com'' ];

  nomadNode = {
    enable = true;
    enablePodman = false;
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


  system.stateVersion = "26.05";
}
