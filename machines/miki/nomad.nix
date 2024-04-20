{ pkgs, ... }: {
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      datacenter = "dusseldorf-contabo"
      client {
        meta {
          box = "miki"
          name = "miki"
        }
        // cpu_total_compute = 10000 # see https://github.com/hashicorp/nomad/issues/18272
        host_network "public" {
          interface           = "ens18"
          reserved_ports      = "22"
        }
        host_volume "immich-db" {
          path      = "/volumes/immich-db/"
          read_only = false
        }
        host_volume "roach" {
          path      = "/roach.d"
          read_only = false
        }
        host_volume "traefik" {
          path      = "/traefik.d"
          read_only = false
        }
      }
      server {
        enabled          = true
        bootstrap_expect = 3
        server_join {
          retry_join = [
            "cosmo.mesh.dcotta.eu",
            "maco.mesh.dcotta.eu",
          ]
          retry_max      = 3
          retry_interval = "15s"
        }
      }
      plugin "docker" {
        config {
          allow_caps = [
            "audit_write", "chown", "dac_override", "fowner", "fsetid", "kill", "mknod",
            "net_bind_service", "setfcap", "setgid", "setpcap", "setuid", "sys_chroot",
            "net_raw", "sys_time",
            "net_admin", "sys_module",
          ]

          # necessary for seaweed
          allow_privileged = true
          # extra Docker labels to be set by Nomad on each Docker container with the appropriate value
          extra_labels = ["job_name", "task_group_name", "task_name", "node_name"]
          volumes {
            enabled = true
          }
        }
      }
    '';
  };


  # to figure out ARM CPU clock speed
  environment.systemPackages = with pkgs; [ dmidecode ];
}
