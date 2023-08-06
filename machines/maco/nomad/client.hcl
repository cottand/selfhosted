client {
  enabled = true

  alloc_dir = "/home/cottand/selfhosted/maco/nomad/alloc/"
  state_dir = "/home/cottand/selfhosted/maco/nomad/client-state"

  servers = ["10.8.0.1", "10.8.0.5", "10.8.0.8"]

  bridge_network_hairpin_mode = true
  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  host_network "vpn" {
    cidr           = "10.8.0.0/24"
    reserved_ports = "22,51820" # wireguard, ssh reserved
  }

  host_volume "docker-sock-ro" {
    path      = "/var/run/docker.sock"
    read_only = true
  }
  host_volume "seaweedfs-volume" {
    path      = "/seaweed.d/volume"
    read_only = false
  }

  meta {
    box              = "maco"
    name             = "maco"
    seaweedfs_volume = true
  }

}
plugin "raw_exec" {
  config {
    enabled = true
  }
}
plugin "docker" {
  config {
    # necessary for seaweed
    allow_privileged = true
    # extra Docker labels to be set by Nomad on each Docker container with the appropriate value
    extra_labels = ["job_name", "task_group_name", "task_name", "node_name"]
  }
}