
job "seaweedfs-sync" {
  datacenters = ["dc1"]

  group "sync" {
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
        image = "chrislusf/seaweedfs:3.53"

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
        image = "chrislusf/seaweedfs:3.53"

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
  }
}