{ util, time, ... }:
{
  job."ente-db-backup" = {
    type = "batch";
    periodic = {
      enabled = true;
      crons = [ "@daily" ];
      prohibitOverlap = true;
    };

    group."backup" = {
      network.mode = "bridge";

      service."ente-db-backup" = {
        port = "9002";
        connect.sidecarService.proxy = {
          upstreams = [
            { destinationName = "ente-db"; localBindPort = 5432; }
          ];
        };
      };

      task."ente-db-backup" = {
        vault.env = true;
        vault.role = "ente-backup-maker";
        driver = "docker";
        config.image = "eeshugerman/postgres-backup-s3:15";
        env.BACKUP_KEEP_DAYS = "7";
        templates = [{
          destination = "config/.env";
          env = true;
          data = ''
            {{ with secret "secret/data/nomad/job/ente/b2" }}
            S3_REGION="us-east-005"
            S3_ACCESS_KEY_ID="{{ .Data.data.keyID }}"
            S3_SECRET_ACCESS_KEY="{{ .Data.data.applicationKey }}"
            S3_BUCKET="cottand-misc-backups"
            S3_ENDPOINT="https://s3.us-east-005.backblazeb2.com"
            S3_PREFIX="ente-db-postgres"
            {{ end }}

            POSTGRES_HOST=localhost
            POSTGRES_PORT=5432

            {{ with secret "secret/data/nomad/job/ente/b2" }}
            POSTGRES_PASSWORD="{{ with secret "secret/data/nomad/job/roach/users/ente" }}{{ .Data.data.password }}{{ end }}"
            {{ end }}
            POSTGRES_USER=ente
            POSTGRES_DATABASE=ente
          '';
        }];
      };
    };
  };
}
