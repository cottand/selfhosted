client {
    enabled = true
    servers = [
      "maco.mesh.dcotta.eu",
      "cosmo.mesh.dcotta.eu",
    ]

    options = {
        "driver.allowlist" = "docker,raw_exec"
    }

    bridge_network_hairpin_mode = true # only 1.5.+

    host_network "vpn" {
        cidr = "10.8.0.0/24"
        reserved_ports = "51820"
    }

    host_network "wg-mesh" {
        cidr = "10.10.0.0/16"
        reserved_ports = "22,55820"
    }

    host_volume "docker-sock-ro" {
        path = "/var/run/docker.sock"
        read_only = true
    }

    # Used for host systemd logs
    host_volume "journald-ro" {
        path = "/var/log/journal"
        read_only = true
    }
    host_volume "machineid-ro" {
        path = "/etc/machine-id"
        read_only = true
    }
    host_volume "seaweedfs-volume" {
        path      = "/seaweed.d/volume"
        read_only = false
    }
    // should be unique across the cluster!
    // host_volume "seaweedfs-filer" {
    //     path      = "/seaweed.d/filer"
    //     read_only = false
    // }

    meta {
        box = "ari"
        name = "ari"
        seaweedfs_volume = true
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
    }
}