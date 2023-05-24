client {
    enabled = true
    servers = ["maco.vpn.dcotta.eu", "ari.vpn.dcotta.eu", "cosmo.vpn.dcotta.eu"]

    options = {
        "driver.allowlist" = "docker,raw_exec"
    }

#    bridge_network_hairpin_mode = true only 1.5.+

    host_network "vpn" {
        cidr = "10.8.0.0/24"
        reserved_ports = "51820"
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

    meta {
        box = "ari"
        name = "ari"
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