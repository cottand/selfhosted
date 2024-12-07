client {
  enabled = true
  servers = [
    # consul should discover nodes!
  ]

  options = {
    "driver.allowlist" = "docker,raw_exec"
  }

  bridge_network_hairpin_mode = true

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

    pull_activity_timeout = "5m"
  }
}

vault {
  enabled               = true
  address = "https://vault.mesh.dcotta.eu:8200" # TODO vault-in-ts?
  jwt_auth_backend_path = "jwt-nomad" # must match tf

  # Provide a default workload identity configuration so jobs don't need to
  # specify one.
  default_identity {
    aud  = ["vault.io"]
    env  = false
    file = false
    ttl  = "6h"
  }
}

consul {
  address              = "127.0.0.1:8501"
  grpc_address         = "127.0.0.1:8503"
  checks_use_advertise = true
  ssl                  = true
  verify_ssl           = false
}