
job "seaweedfs-backup" {
  datacenters = ["*"]

  group "backup" {
    network {
      mode = "bridge"
      port "metrics" {}
    }
    count = 1
    restart {
      interval = "10m"
      attempts = 5
      delay    = "15s"
      mode     = "delay"
    }
    service {
        name = "seaweed-backup"
        port = "metrics"

        connect {
          sidecar_service {
            proxy {
              upstreams {
                destination_name = "seaweed-filer-http"
                local_bind_port  = 8888
              }
              upstreams {
                destination_name = "seaweed-filer-grpc"
                local_bind_port  = 18888
              }
            }
          }
        }
    }
    task "backup" {

      driver = "docker"
      config {
        image = "chrislusf/seaweedfs:3.57"

        args = [
          "-logtostderr",
          "filer.backup",
          "-filer=localhost:8888.18888",
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
directory = "/snapshot2/"    # destination directory - snapshot := non incremental
is_incremental = false 
EOF
      }
      // template {
      //   destination = "env"
      //   change_mode = "restart"
      //   env = true
      //   data = <<-EOF
      //   {{ range $i, $s := service "seaweed-filer-http" }}
      //   FILER_ADDR="{{ .Address }}:{{ .Port }}"
      //   {{ end }}
      //   EOF
      // }
      resources {
        cpu    = 150
        memory = 120
      }
    }
  }
}