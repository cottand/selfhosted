client {
  enabled = true

  alloc_dir = "/root/selfhosted/cosmo/nomad/alloc/"
  state_dir = "/var/lib/nomad-client-state"

  servers = ["maco.vpn.dcotta.eu", "cosmo.vpn.dcotta.eu"]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  host_network "vpn" {
    cidr = "10.8.0.0/24"
    reserved_ports = "51820"
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
  host_volume "docker-sock-ro" {
    path = "/var/run/docker.sock"
    read_only = true
  }

  meta {
    box = "cosmo"
    name = "cosmo"
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