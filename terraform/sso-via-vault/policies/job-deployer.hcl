namespace "*" {
  policy = "read"
  capabilities = [
    "list-jobs",
    "read-job",
    "read-fs",
    "plan-job",
    "csi-mount-volume",
    "csi-write-volume",

    "submit-job",
    "dispatch-job",
  ]
}

# allows mounting read-write
host_volume "*" {
  policy = "write"
}
