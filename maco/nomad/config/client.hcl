client {
  enabled = true

  alloc_dir = "/home/cottand/selfhosted/maco/nomad/alloc/"
  state_dir = "/var/lib/nomad-client-state"

  servers = ["10.8.0.1"]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  host_network "vpn" {
    cidr = "10.8.0.0/24"
    reserved_ports = "22,51820"
  }

  host_volume "postgres" {
    path = "/home/cottand/selfhosted/maco/volumes/postgres/"
    read_only = "false"
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
