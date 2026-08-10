{ util, time, defaults, ... }:
let
  resources = {
    cpu = 100;
    memory = 256;
    memoryMax = 512;
  };
  ports = {
    http = 8080;
    db = 5432;
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 resources;
  otlpPort = 9001;
  bind = util.localhost;

  restart = {
    attempts = 3;
    interval = 10 * time.minute;
    delay = 15 * time.second;
    mode = "delay";
  };

  host = "files.dcotta.com";
  b2Endpoint = "https://s3.us-east-005.backblazeb2.com";
in
{
  job."safebucket" = {

    group."safebucket" = {
      inherit restart;
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };

      service."safebucket-http" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "roach-db"; localBindPort = ports.db; }
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-safebucket-http";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "safebucket-health";
          port = "health";
          type = "http";
          path = "/";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];

        tags = [
        ## Notes
        ## API paths that should be ok to be public
        ## /shares/
        ## /api/v1/shares
        ## /assets/
        ##
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.safebucket-http.entrypoints=web,websecure,cloudflared"
          "traefik.http.routers.safebucket-http.rule=Host(`${host}`)"
          "traefik.http.routers.safebucket-http.tls=true"
          "traefik.http.routers.safebucket-http.middlewares=safebucket-csp"
          "traefik.http.middlewares.safebucket-csp.headers.customResponseHeaders.Content-Security-Policy=default-src 'self'; media-src 'self' ${b2Endpoint}; img-src 'self' ${b2Endpoint} data: blob:; connect-src 'self' ${b2Endpoint}; frame-src 'self' ${b2Endpoint} blob: data:; object-src 'self' ${b2Endpoint} blob: data:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; font-src 'self' data:"

          "traefik.http.routers.safebucket-banner.entrypoints=web,websecure,cloudflared"
          "traefik.http.routers.safebucket-banner.rule=Host(`${host}`) && Path(`/safebucket_banner.png`)"
          "traefik.http.routers.safebucket-banner.tls=true"
          "traefik.http.routers.safebucket-banner.service=github-raw@file"
          "traefik.http.routers.safebucket-banner.middlewares=safebucket-banner-path"
          "traefik.http.middlewares.safebucket-banner-path.replacepath.path=/cottand/selfhosted/refs/heads/master/misc/dcotta-subsystems-cropped.png"
        ];
      };

      task."safebucket" = {
        vault = { };
        driver = "docker";
        config = {
          image = "ghcr.io/safebucket/safebucket:0.7.2";
          volumes = [ "local/config.yaml:/config.yaml" ];
        };

        inherit resources;

        env = {
          CONFIG_FILE_PATH = "/config.yaml";
        };
        user = "root:root";

        templates = [
          {
            destination = "local/config.yaml";
            changeMode = "restart";
            data = ''
              app:
                api_url: https://${host}
                web_url: https://${host}
                port: ${toString ports.http}
                allowed_origins: https://${host}
                cookie_secure_force: true
                {{ with secret "secret/data/nomad/job/safebucket/auth" }}
                token_secret: {{ .Data.data.secret }}
                admin_email: {{ .Data.data.admin_email }}
                admin_password: {{ .Data.data.admin_password }}
                mfa_encryption_key: {{ .Data.data.mfa_encryption_key }}
                {{ end }}

              database:
                type: postgres
                postgres:
                  name: safebucket
                  host: ${bind}
                  port: ${toString ports.db}
                  user: safebucket
                  sslmode: verify-ca
                  {{ with secret "secret/data/nomad/job/roach/users/safebucket" }}
                  password: "{{ .Data.data.password }}"
                  {{ end }}

              {{ with secret "secret/data/nomad/job/safebucket/b2" }}
              storage:
                type: s3
                s3:
                  bucket_name: {{ .Data.data.bucket }}
                  endpoint: {{ .Data.data.endpoint }}
                  external_endpoint: https://{{ .Data.data.endpoint }}
                  access_key: {{ .Data.data.keyID }}
                  secret_key: {{ .Data.data.applicationKey }}
                  force_path_style: true
                  region: {{ .Data.data.region }}
              {{ end }}

              cache:
                type: memory
              events:
                type: memory
                queues:
                  notifications:
                    name: safebucket-notifications
                  bucket_events:
                    name: safebucket-notifications-2
                  object_deletion:
                    name: safebucket-notifications-3

              notifier:
                type: filesystem
                filesystem:
                  directory: {{env "NOMAD_TASK_DIR" }}/notifications
              activity:
                filesystem:
                  directory: {{env "NOMAD_TASK_DIR" }}/activity
                type: filesystem

              auth:
                providers:
                  keys: local
                  local:
                    name: local
                    type: local
                    sharing_allowed: true

            '';
          }
          {
            destination = "/secrets/env";
            changeMode = "restart";
            env = true;
            data = ''
              PGSSLMODE=verify-ca
              PGSSLSNI=roach-db.tfk.nd
              PGSSLKEY=/secrets/client.safebucket.key
              PGSSLCERT=/secrets/client.safebucket.crt
              PGSSLROOTCERT=/secrets/ca.crt
              PGDATABASE=safebucket
            '';
          }
          {
            destination = "/secrets/client.safebucket.key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/safebucket"}}{{.Data.data.key}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/client.safebucket.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/safebucket"}}{{.Data.data.chain}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/ca.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/safebucket"}}{{.Data.data.ca}}{{end}}
            '';
            perms = "0600";
          }
        ];
      };
    };
  };
}
