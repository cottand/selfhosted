namespace "*" {
  policy       = "write"
  capabilities = ["list-jobs", "read-job", "dispatch-job", "alloc-lifecycle", "submit-job", "alloc-exec", "scale-job", "read-fs", "csi-mount-volume", "csi-write-volume", "alloc-node-exec", "read-fs"]
}

agent {
  policy = "write"
}

operator {
  policy = "write"
}

quota {
  policy = "write"
}

node {
  policy = "write"
}

host_volume "*" {
  policy = "write"
}

plugin {
  policy = "list"
}