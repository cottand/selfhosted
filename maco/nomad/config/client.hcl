client {
  enabled = true

  alloc_dir = "/home/cottand/selfhosted/maco/nomad/alloc/"
  state_dir = "/home/cottand/selfhosted/maco/nomad/client-state"

  servers = ["cosmo.vpn.dcotta.eu", "maco.vpn.dcotta.eu"]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  host_network "vpn" {
    cidr = "10.8.0.0/24"
    reserved_ports = "22,51820" # wireguard, ssh reserved
  }

  host_volume "postgres" {
    path = "/home/cottand/selfhosted/maco/volumes/postgres/"
    read_only = "false"
  }
  host_volume "loki" {
    path = "/home/cottand/selfhosted/maco/volumes/loki/"
    read_only = "false"
  }

  host_volume "docker-sock-ro" {
    path = "/var/run/docker.sock"
    read_only = true
  }

  meta {
    box = "maco"
    name = "maco"
  }
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}
plugin "docker" {
  config {
    # extra Docker labels to be set by Nomad on each Docker container with the appropriate value
    extra_labels = ["job_name", "task_group_name", "task_name", "node_name"]
  }
}
