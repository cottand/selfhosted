server {
  enabled          = true
  bootstrap_expect = 2
  server_join {
    retry_join = [
      // "10.10.0.1",
      "cosmo.mesh.dcotta.eu",
      // "ari.mesh.dcotta.eu",
      //  "10.10.3.1"
    ]
    retry_max      = 3
    retry_interval = "15s"
  }
}
# binaries shouldn't go in /var/lib
plugin_dir = "/nomad.d/plugins"
data_dir   = "/nomad.d/data"

// bind_addr = "10.10.2.1"
bind_addr = "0.0.0.0"

advertise {
  #   Defaults to the first private IP address.
  // http = "10.10.2.1"
  // rpc  = "10.10.2.1"
  // serf = "10.10.2.1" # non-default ports may be specified
  http = "{{GetInterfaceIP \"wg-mesh\"}}"
  rpc  = "{{GetInterfaceIP \"wg-mesh\"}}"
  serf = "{{GetInterfaceIP \"wg-mesh\"}}"
  // http = "10.10.2.1"
  // rpc  = "10.10.2.1"
  // serf = "10.10.2.1" # non-default ports may be specified
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