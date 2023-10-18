job "immich-db-backup" {
  type = "batch"
  periodic {
    cron             = "@daily"
    prohibit_overlap = true
  }

  task "lemmy-backup" {
    driver = "docker"
    config {
      image = "eeshugerman/postgres-backup-s3:15"
    }
    env {
      BACKUP_KEEP_DAYS = 7 # optional
    }
    template {
      destination = "config/.env"
      env         = true
      data        = <<-EOF
        {{ with nomadVar "secret/buckets/immich-db" }}
        S3_REGION="us-east-005"
        S3_ACCESS_KEY_ID="{{ .keyId }}"
        S3_SECRET_ACCESS_KEY="{{ .secretAccessKey }}"
        S3_BUCKET="{{ .bucketName }}"
        S3_ENDPOINT="https://{{ .endpoint }}"
        S3_PREFIX="backup"
        {{ end }}
        {{ range nomadService "immich-db" }}
        POSTGRES_HOST={{ .Address }}
        POSTGRES_PORT={{ .Port }}
        {{ end }}
        {{ with nomadVar "nomad/jobs/immich" }}
        POSTGRES_PASSWORD={{ .db_password }}
        POSTGRES_USER={{ .db_user }}
        {{ end }}
        POSTGRES_DATABASE=immich
        EOF
    }
  }
}