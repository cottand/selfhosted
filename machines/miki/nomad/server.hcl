server {
  enabled          = false
  bootstrap_expect = 2
  server_join {
    retry_join = [
      "maco.mesh.dcotta.eu",
      "cosmo.mesh.dcotta.eu",
      "ari.mesh.dcotta.eu",
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
}

log_rotate_bytes = 102400

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
