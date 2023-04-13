client {
  enabled = true

  alloc_dir = "/var/lib/nomad-alloc"
  state_dir = "/var/lib/nomad-client-state"

  servers = ["10.8.0.1"]

  options = {
    "driver.allowlist" = "docker"
  }

  host_network "vpn" {
    cidr = "10.8.0.0/24"
    reserved_ports = "22,80,443,51820"
  }

  host_volume "wireguard" {
    path = "/etc/nomad-volumes/wireguard"
    read_only = false
  }

  meta {
    box = "cosmo"
    name = "cosmo"
  }
}