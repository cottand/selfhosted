{ ... }: {
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      datacenter = "dusseldorf-contabo"
      client {
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
}
