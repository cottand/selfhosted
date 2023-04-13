server {
  enabled = true
  bootstrap_expect = 1
}

data_dir  = "/var/lib/nomad"

bind_addr = "10.8.0.1"

advertise {
  # Defaults to the first private IP address.
  http = "10.8.0.1"
  rpc  = "10.8.0.1"
  serf = "10.8.0.1:5648" # non-default ports may be specified
}

log_rotate_bytes = 10240

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}
