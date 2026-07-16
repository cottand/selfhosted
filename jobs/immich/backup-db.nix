{ util, time, ... }:
{
  job."immich-db-backup" = {
    type = "batch";
    periodic = {
      cron = "@daily";
      prohibitOverlap = true;
    };

    group."backup" = {
      network.mode = "bridge";

      service."immich-db-backup" = {
        port = "9002";
        connect.sidecarService.proxy = {
          upstreams = [
            { destinationName = "immich-postgres"; localBindPort = 5432; }
          ];
        };
      };

      task."immich-backup" = {
        driver = "docker";
        config.image = "eeshugerman/postgres-backup-s3:15";
        env.BACKUP_KEEP_DAYS = "7";
        templates = [{
          destination = "config/.env";
          env = true;
          data = ''
            {{ with nomadVar "secret/buckets/immich-db" }}
            S3_REGION="us-east-005"
            S3_ACCESS_KEY_ID="{{ .keyId }}"
            S3_SECRET_ACCESS_KEY="{{ .secretAccessKey }}"
            S3_BUCKET="{{ .bucketName }}"
            S3_ENDPOINT="https://{{ .endpoint }}"
            S3_PREFIX="backup"
            {{ end }}
            POSTGRES_HOST=localhost
            POSTGRES_PORT=5432
            {{ with nomadVar "nomad/jobs/immich" }}
            POSTGRES_PASSWORD={{ .db_password }}
            POSTGRES_USER={{ .db_user }}
            {{ end }}
            POSTGRES_DATABASE=immich
          '';
        }];
      };
    };
  };
}
