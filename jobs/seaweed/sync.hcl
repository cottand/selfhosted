
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
          "-filer=${SEAWEEDFS_FILER_IP_http}:${SEAWEEDFS_FILER_PORT_http}",
        ]
      }
      template {
        destination = "config/.env"
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
          "-filer=${SEAWEEDFS_FILER_IP_http}:${SEAWEEDFS_FILER_PORT_http}",
        ]
      }
      template {
        destination = "config/.env"
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
      resources {
        cpu    = 100
        memory = 80
      }
    }
  }
}