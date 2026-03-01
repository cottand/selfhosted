namespace "default" {
  policy       = "read"
  capabilities = ["submit-job"]
}

# allow deploying to any host volume
host_volume "*" {
  policy = "write"
}