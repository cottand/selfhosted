data_dir = "/var/lib/nomad"

# bind_addr = "{{GetInterfaceIP \"wg-mesh\"}}"
bind_addr = "{{GetInterfaceIP \"ts0\"}}"
 # bind_addr = "0.0.0.0"

advertise {
  http = "{{GetInterfaceIP \"ts0\"}}"
  rpc  = "{{GetInterfaceIP \"ts0\"}}"
  serf = "{{GetInterfaceIP \"ts0\"}}"
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
  enabled = true
}
