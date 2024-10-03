resource "nomad_csi_volume" "filestash" {
  name      = "filestash"
  volume_id = "filestash"

  plugin_id = "seaweedfs"

  # dont try to set this to less than 1GiB
  capacity_min = "200GiB"
  capacity_max = "200GiB"

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }

  mount_options {
    fs_type     = "ext4"
    mount_flags = ["rw"]
  }
  parameters = {
    replication = 010
  }

  lifecycle {
    prevent_destroy = true
  }
}
