# file docs: https://developer.hashicorp.com/nomad/docs/other-specifications/volume

id        = "traefik-cert"
name      = "traefik-cert"
type      = "csi"

plugin_id = "seaweedfs"

# dont try to set this to less than 1GiB
capacity_min = "2GiB"
capacity_max = "3GiB"

capability {
  access_mode     = "multi-node-single-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "ext4"
  mount_flags = ["rw"]
}

# documented at https://github.com/seaweedfs/seaweedfs-csi-driver
parameters {
  collection = ""
  replication = "020"
}
