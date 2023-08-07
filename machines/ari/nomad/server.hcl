server {
    enabled = true
    bootstrap_expect = 3
    server_join {
        retry_join = ["10.10.0.1", "10.10.2.1"]
        retry_max = 3
        retry_interval = "15s"
    }
}

data_dir  = "/var/lib/nomad"

bind_addr = "10.10.3.1"

advertise {
    #   Defaults to the first private IP address.
    http = "10.10.3.1"
    rpc  = "10.10.3.1"
    serf = "10.10.3.1"
}

log_rotate_bytes = 1024000

ports {
    http = 4646
    rpc  = 4647
    serf = 4648
}

telemetry {
    collection_interval = "5s"
    disable_hostname = true
    prometheus_metrics = true
    publish_allocation_metrics = true
    publish_node_metrics = true
}

acl {
    // enabled = true
}
