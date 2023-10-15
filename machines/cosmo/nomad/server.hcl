server {
  enabled          = true
  bootstrap_expect = 1
  server_join {
    retry_join = [
      // "maco.mesh.dcotta.eu"
    ]
    retry_max      = 3
    retry_interval = "15s"
  }
}

# binaries shouldn't go in /var/lib
plugin_dir = "/usr/lib/nomad/plugins"
data_dir   = "/var/lib/nomad"

# bind_addr = "10.10.0.1"
bind_addr = "0.0.0.0"
#bind_addr = "127.0.0.1"

advertise {
  http = "{{GetInterfaceIP \"wg-mesh\"}}"
  rpc  = "{{GetInterfaceIP \"wg-mesh\"}}"
  serf = "{{GetInterfaceIP \"wg-mesh\"}}"
  #   Defaults to the first private IP address.
  // http = "10.10.0.1"
  // rpc  = "10.10.0.1"
  // serf = "10.10.0.1" # non-default ports may be specified
}

log_rotate_bytes = 1024000

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

telemetry {
  collection_interval        = "5s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}

acl {
  // enabled = true
}
