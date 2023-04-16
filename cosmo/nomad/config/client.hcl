client {
  enabled = true

  alloc_dir = "/root/selfhosted/cosmo/nomad/alloc/"
  state_dir = "/var/lib/nomad-client-state"

  servers = ["10.8.0.1"]

  options = {
    "driver.allowlist" = "docker"
  }

  host_network "vpn" {
    cidr = "10.8.0.0/24"
    reserved_ports = "22,80,443,51820"
  }

  host_volume "traefik-cert" {
    path = "/root/selfhosted/cosmo/volumes/traefik-cert"
    read_only = "false"
  }
  host_volume "traefik-basic-auth" {
    path = "/root/selfhosted/cosmo/volumes/traefik-basic-auth"
    read_only = "true"
  }
  host_volume "grafana" {
    path = "/root/selfhosted/cosmo/volumes/grafana"
    read_only = "false"
  }

  meta {
    box = "cosmo"
    name = "cosmo"
  }
}