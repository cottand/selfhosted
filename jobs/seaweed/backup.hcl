
job "seaweedfs-backup" {
  datacenters = ["dc1"]

  group "backup" {
    count = 1
    restart {
      interval = "10m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    task "backup" {

      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:3.51"

        args = [
          "-logtostderr",
          "filer.backup",
          "-filer=${SEAWEEDFS_FILER_IP_http}:${SEAWEEDFS_FILER_PORT_http}",
        ]
        mount {
          type   = "bind"
          source = "local"
          target = "/etc/seaweedfs/"
        }
      }
      template {
        destination = "local/replication.toml"
        change_mode = "restart"
        data        = <<-EOF
[sink.s3]
enabled = true
{{ with nomadVar "secret/buckets/seaweedfs-bu" }}
aws_access_key_id     = "{{ .keyId }}"
aws_secret_access_key = "{{ .secretAccessKey }}"     # if empty, loads from the shared credentials file (~/.aws/credentials).
bucket = "{{ .bucketName }}"
endpoint = "https://{{ .endpoint }}"
{{ end }}
region = "us-east-005"
directory = "/snapshot/"    # destination directory - snapshot := non incremental
is_incremental = false 
EOF
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