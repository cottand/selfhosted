client {
  enabled = true

  servers = ["10.10.0.1", "10.10.2.1"
  // , "10.10.3.1"
  ]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  bridge_network_hairpin_mode = true # only 1.5.+

  host_network "vpn" {
    cidr           = "10.8.0.0/24"
    reserved_ports = "51820"
  }
  host_network "wg-mesh" {
    cidr           = "10.10.0.0/16"
    reserved_ports = "22,55820"
  }
  host_volume "traefik-cert" {
    path      = "/root/nomad-volumes/traefik-cert"
    read_only = "false"
  }
  host_volume "traefik-basic-auth" {
    path      = "/root/nomad-volumes/traefik-basic-auth"
    read_only = "true"
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
  host_volume "lemmy-data" {
    path      = "/lemmy.d/data"
    read_only = false
  }
  host_volume "grafana-cosmo" {
    path      = "/grafana.d"
    read_only = false
  }

  meta {
    box              = "cosmo"
    name             = "cosmo"
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
    volumes {
      enabled = true
    }
  }
}