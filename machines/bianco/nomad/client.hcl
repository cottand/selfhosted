client {
  enabled = true
  servers = [
    "cosmo.mesh.dcotta.eu",
    "maco.mesh.dcotta.eu",
  ]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  bridge_network_hairpin_mode = true

  host_network "vpn" {
    cidr           = "10.8.0.0/24"
    reserved_ports = "22,51820"
  }
  host_network "wg-mesh" {
    cidr           = "10.10.0.0/16"
    reserved_ports = "22,55820"
  }

  host_volume "docker-sock-ro" {
    path      = "/var/run/docker.sock"
    read_only = true
  }

  # Used for host systemd logs
  host_volume "journald-ro" {
    path      = "/var/log/journal"
    read_only = true
  }
  host_volume "machineid-ro" {
    path      = "/etc/machine-id"
    read_only = true
  }
  host_volume "seaweedfs-volume" {
    path      = "/seaweed.d/volume"
    read_only = false
  }
  meta {
    box               = "bianco"
    name              = "bianco"
    seaweedfs_volume  = true
    docker_privileged = true
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


data_dir = "/var/lib/nomad"

telemetry {
  collection_interval        = "5s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}
bind_addr = "0.0.0.0"

advertise {
  http = "{{GetInterfaceIP \"wg-mesh\"}}"
  rpc  = "{{GetInterfaceIP \"wg-mesh\"}}"
  serf = "{{GetInterfaceIP \"wg-mesh\"}}"
}

log_rotate_bytes = 1024000

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}
