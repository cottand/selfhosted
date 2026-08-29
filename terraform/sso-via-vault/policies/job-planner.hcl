namespace "*" {
  policy = "read"
  capabilities = [
    "list-jobs",
    "read-job",
    "read-fs",
    "plan-job",
    "csi-mount-volume",
    "csi-write-volume",
  ]
}
