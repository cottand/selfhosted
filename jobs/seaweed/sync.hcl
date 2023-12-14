
variable "seaweedfs_version" {
  type    = string
  default = "3.57"
}
job "seaweedfs-sync" {
  datacenters = ["*"]

  group "sync" {
    network {
      dns {
        servers = ["10.10.0.1", "10.10.2.1", "10.10.4.1", ]
      }
    }
    count = 1
    restart {
      interval = "10m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    task "sync-buckets" {
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:${var.seaweedfs_version}"

        args = [
          "-logtostderr",
          "filer.remote.sync", "-dir=/buckets",
          "-filer=seaweedfs-filer-http.nomad:8888",
        ]
      }
      resources {
        cpu    = 100
        memory = 80
      }
    }
    task "sync-documents" {
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:${var.seaweedfs_version}"

        args = [
          "-logtostderr",
          "filer.remote.sync", "-dir=/documents/",
          "-filer=seaweedfs-filer-http.nomad:8888",
        ]
      }
      resources {
        cpu    = 100
        memory = 80
      }
    }
    task "sync-backup" {
      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:${var.seaweedfs_version}"

        args = [
          "-logtostderr",
          "filer.remote.sync", "-dir=/backup/",
          "-filer=seaweedfs-filer-http.nomad:8888",
        ]
      }
      resources {
        cpu    = 100
        memory = 80
      }
    }
  }
}