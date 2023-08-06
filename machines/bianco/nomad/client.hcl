client {
    enabled = true
    servers = ["10.8.0.1", "10.8.0.5", "10.8.0.8"]

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
    host_volume "seaweedfs-volume" {
        path      = "/seaweed.d/volume"
        read_only = false
    }

    meta {
        box = "bianco"
        name = "bianco"
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


data_dir  = "/var/lib/nomad"

telemetry {
    collection_interval = "5s"
    disable_hostname = true
    prometheus_metrics = true
    publish_allocation_metrics = true
    publish_node_metrics = true
}
bind_addr = "10.8.0.102"

advertise {
    #   Defaults to the first private IP address.
    http = "10.8.0.102"
    rpc  = "10.8.0.102"
    serf = "10.8.0.102" 
}

log_rotate_bytes = 1024000

ports {
    http = 4646
    rpc  = 4647
    serf = 4648
}