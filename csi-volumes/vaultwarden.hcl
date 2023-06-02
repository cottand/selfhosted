id        = "swfs-vaultwarden"
name      = "vaultwarden-csi"
type      = "csi"

plugin_id = "seaweedfs"

# dont try to set this to less than 1GiB
capacity_min = "5GiB"
capacity_max = "8GiB"

capability {
  access_mode     = "single-node-reader-only"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "ext4"
  mount_flags = ["rw"]
}

parameters {
  collection = ""
  // replication = "010"
}
