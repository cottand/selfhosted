{ config, pkgs, ... }:
{
  systemd.tmpfiles.rules = [
    "d /roach.d 1777 root root -"
  ];

  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      datacenter = "dusseldorf-contabo"
      client {
        meta {
          box              = "cosmo"
          name             = "cosmo"
          seaweedfs_volume = true
          public_network   = true
          docker_privileged = true
        }
        host_volume "roach" {
          path      = "/roach.d"
          read_only = false
        }
        host_network "public" {
          interface           = "ens18"
          reserved_ports      = "22"
        }
      }
      plugin_dir = "/usr/lib/nomad/plugins"
      data_dir   = "/var/lib/nomad"
      bind_addr = "0.0.0.0"
    '';
  };
}
