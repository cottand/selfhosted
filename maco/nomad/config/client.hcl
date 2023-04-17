client {
  enabled = true

  alloc_dir = "/home/cottand/selfhosted/maco/nomad/alloc/"
  state_dir = "/var/lib/nomad-client-state"

  servers = ["10.8.0.1"]

  options = {
    "driver.allowlist" = "docker"
  }

  host_network "vpn" {
    cidr = "10.8.0.0/24"
    reserved_ports = "22,51820"
  }

  meta {
    box = "maco"
    name = "maco"
  }
}