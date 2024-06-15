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
      }
      plugin_dir = "/usr/lib/nomad/plugins"
      data_dir   = "/var/lib/nomad"
      server {
        enabled          = true
        bootstrap_expect = 0
        server_join {
          retry_join = [
            "maco.mesh.dcotta.eu"
          ]
          retry_max      = 3
          retry_interval = "15s"
          }
      }
      bind_addr = "0.0.0.0"
    '';
  };
}
