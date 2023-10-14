client {
  enabled = true

  servers = [
    "maco.mesh.dcotta.eu",
    "cosmo.mesh.dcotta.eu",
    "ari.mesh.dcotta.eu",
  ]

  options = {
    "driver.allowlist" = "docker"
  }

  cpu_total_compute = 10000 # see https://github.com/hashicorp/nomad/issues/18272

  bridge_network_hairpin_mode = true # only 1.5.+

  // host_network "vpn" { no VPN on miki! 
  //   cidr           = "10.8.0.0/24"
  //   reserved_ports = "51820"
  // }
  host_network "wg-mesh" {
    cidr           = "10.10.0.0/16"
    reserved_ports = "22,55820"
  }
  host_volume "docker-sock-ro" {
    path      = "/var/run/docker.sock"
    read_only = true
  }
  host_volume "seaweedfs-volume" {
    path      = "/seaweed.d/volume"
    read_only = false
  }
  host_volume "seaweedfs-filer" {
    path      = "/seaweed.d/filer"
    read_only = false
  }
  host_volume "immich-db" {
    path      = "/volumes/immich-db/"
    read_only = false
  }
  meta {
    box              = "miki"
    name             = "miki"
    seaweedfs_volume = true
    public_network   = true
  }
}
// plugin "raw_exec" {
//   config {
//     enabled = true
//   }
// }
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