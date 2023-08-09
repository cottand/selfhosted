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

  group "nodes" {
    network {
      dns {
        servers = [
          "10.8.0.1",
          "10.10.2.1",
          "10.10.1.1",
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

      template {
        destination = "config/.env"
        change_mode = "restart"
        env         = true
        data        = <<-EOF
{{ range $i, $s := nomadService "seaweedfs-filer-http" }}
{{- if eq $i 0 -}}
SEAWEEDFS_FILER_IP_http={{ .Address }}
SEAWEEDFS_FILER_PORT_http={{ .Port }}
{{- end -}}
{{ end }}
{{ range $i, $s := nomadService "seaweedfs-filer-grpc" }}
{{- if eq $i 0 -}}
SEAWEEDFS_FILER_IP_grpc={{ .Address }}
SEAWEEDFS_FILER_PORT_grpc={{ .Port }}
{{- end -}}
{{ end }}
EOF
      }

      config {
        network_mode = "host"
        image        = "chrislusf/seaweedfs-csi-driver:v1.1.5"
        force_pull   = "true"

        args = [
          // "--controller",
          // "--node",
          "--endpoint=unix://csi/csi.sock",
          // hardcoded ports and IP so that this does not get restarted when master does
          "--filer=seaweedfs-filer.vps:8888.18888",
          "--nodeid=${node.unique.name}",
          "--cacheCapacityMB=1000",
          "--cacheDir=${NOMAD_TASK_DIR}/cache_dir",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "seaweedfs"
        type      = "monolith"
        mount_dir = "/csi"
      }
      resources {
        cpu        = 100
        memory     = 512
        memory_max = 2048
      }
    }
  }
}