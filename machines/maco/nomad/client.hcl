client {
  enabled = true

  alloc_dir = "/nomad.d/alloc/"
  state_dir = "/nomad.d/client-state"

  servers = [
    "10.10.0.1",
     "10.10.2.1",
      // "10.10.3.1",
      ]

  bridge_network_hairpin_mode = true
  options = {
    "driver.allowlist" = "docker,raw_exec"
    "docker.volumes.enabled" = true
  }

  host_network "wg-mesh" {
    cidr           = "10.10.0.0/16"
    reserved_ports = "22,55820"
  }
  host_volume "docker-sock-ro" {
    path      = "/var/run/docker.sock"
    read_only = true
  }
  meta {
    box              = "maco"
    name             = "maco"
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
