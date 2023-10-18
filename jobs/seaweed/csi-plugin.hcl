job "seaweedfs-plugin" {
  datacenters = ["dc1"]
  type        = "system"
  update {
    max_parallel = 1
    stagger      = "60s"
  }

  # only one plugin of a given type and ID should be deployed on
  # any given client node
  constraint {
    operator = "distinct_hosts"
    value    = true
  }

  group "plugin" {
    network {
      dns {
        servers = [
          "10.10.0.1",
          "10.10.1.1",
          "10.10.2.1",
          "10.10.4.1",
        ]
      }
    }
    ephemeral_disk {
      migrate = false
      size    = 5000
      sticky  = false
    }
    restart {
      interval = "5m"
      attempts = 10
      delay    = "15s"
      mode     = "delay"
    }
    # does not need to run on a client with seaweed, only needs docker privileged
    task "plugin" {
      driver = "docker"

      config {
        network_mode = "host"
        image        = "chrislusf/seaweedfs-csi-driver:v1.1.8"
        force_pull   = "true"

        args = [
          // "--controller",
          // "--node",
          "--endpoint=unix://csi/csi.sock",
          // hardcoded ports and IP so that this does not get restarted when master does
          "--filer=seaweedfs-filer-http.nomad:8888.18888",
          "--nodeid=${node.unique.name}",
          "--cacheCapacityMB=2000",
          "--cacheDir=/data/cache_dir",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "seaweedfs"
        type      = "monolith"
        mount_dir = "/csi"
      }
      resources {
        cpu        = 512
        memory     = 512
        memory_max = 1024
      }
    }
  }
}