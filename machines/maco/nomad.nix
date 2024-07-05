{ ... }: {
  systemd.tmpfiles.rules = [ "d /nomad.d 1777 root root -" ];
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      datacenter = "dusseldorf-contabo"
      client {
        host_volume "traefik" {
          path      = "/traefik.d"
          read_only = false
        }
        meta {
          box = "maco"
          name = "maco"
        }
        alloc_dir = "/nomad.d/alloc/"
        state_dir = "/nomad.d/client-state"
        host_volume "roach" {
          path      = "/roach.d"
          read_only = false
        }
      }
      # binaries shouldn't go in /var/lib
      plugin_dir = "/nomad.d/plugins"
      data_dir   = "/nomad.d/data"
    '';
  };
}
