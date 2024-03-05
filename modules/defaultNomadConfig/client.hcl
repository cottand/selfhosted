client {
  enabled = true
  servers = [
    "maco.mesh.dcotta.eu",
    "cosmo.mesh.dcotta.eu",
  ]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  bridge_network_hairpin_mode = true

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
  host_volume "ca-certificates" {
    path      = "/etc/ssl/certs"
    read_only = true
  }
  meta {
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

vault {
  enabled = true
  address = "https://vault.mesh.dcotta.eu:8200"
  jwt_auth_backend_path = "jwt-nomad" # must match tf

  # Provide a default workload identity configuration so jobs don't need to
  # specify one.
  default_identity {
    aud  = [ "vault.io" ]
    env  = true
    file = true
    ttl  = "1h"
  }
}