{ config, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./ipv6.nix
    ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  networking.hostName = "maco";

  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    usbutils
    pciutils
    iw
  ];
  #networking.firewall.allowedUDPPorts = [ 51820 4647 4648 ];
  networking.firewall.enable = true;
  networking.firewall = {
    # WG whitelisted in lib/make-wireguard
    allowedTCPPorts = [ 22 ];
    # for wg-ui VPN
    allowedUDPPorts = [ 51825 ];
  };

  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      client {
        meta {
          box = "maco"
          name = "maco"
        }
        alloc_dir = "/nomad.d/alloc/"
        state_dir = "/nomad.d/client-state"
      }
      server {
        enabled          = true
        bootstrap_expect = 2
        server_join {
          retry_join = [
            "cosmo.mesh.dcotta.eu",
          ]
          retry_max      = 3
          retry_interval = "15s"
        }
      }
      # binaries shouldn't go in /var/lib
      plugin_dir = "/nomad.d/plugins"
      data_dir   = "/nomad.d/data"
    '';
  };

  virtualisation.docker.enable = true;
  networking.firewall.checkReversePath = false;

  system.stateVersion = "23.05";
}
