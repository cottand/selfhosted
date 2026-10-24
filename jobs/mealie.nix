{ util, time, defaults, ... }:
let
  version = "v3.28.0";
  rcloneVersion = "1.75.1";
  litestreamVersion = "0.5.17";
  cpu = 200;
  mem = 512;
  ports = {
    http = 9000;
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 {
    inherit cpu;
    memory = mem;
    memoryMax = mem * 2;
  };
  otlpPort = 9001;

  # host path <alloc>/alloc/data is bind-mounted at this path in the rclone and mealie tasks
  # so that the FUSE mount made by rclone propagates into the mealie container
  sharedRoot = "/b2root";
  b2Dir = "${sharedRoot}/mnt";

  # mealie's DATA_DIR lives on local alloc disk so that SQLite never touches the FUSE mount;
  # file directories are symlinked into the B2 mount and the DB is replicated by litestream
  dataDir = "/alloc/data/mealie";
  dbPath = "${dataDir}/mealie.db";
  b2Subdirs = [ "recipes" "users" "groups" "backups" "templates" ];
  secretFiles = [ ".secret" ".session_secret" ];

  litestreamConfig = {
    destination = "secrets/litestream.yml";
    changeMode = "restart";
    data = ''
      dbs:
        - path: ${dbPath}
          replica:
            type: s3
      {{ with secret "secret/data/nomad/job/mealie/b2" }}
            bucket: {{ .Data.data.bucket }}
            path: db
            endpoint: https://{{ .Data.data.endpoint }}
            region: {{ .Data.data.region }}
            access-key-id: {{ .Data.data.keyID }}
            secret-access-key: {{ .Data.data.applicationKey }}
      {{ end }}
    '';
  };
  litestreamResources = {
    cpu = 50;
    memory = 64;
    memoryMax = 256;
  };
in
{
  job."mealie" = {
    constraints = [{
      attribute = "\${node.datacenter}";
      operator = "!=";
      value = "nuremberg-hetzner";
    }];
    group."mealie" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."health".hostNetwork = "ts";
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      ephemeralDisk.size = 2000;

      service."mealie" = {
        port = toString ports.http;
        connect = {
          sidecarService.proxy = {
            upstreams = [
              { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
            ];
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-mealie";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
          sidecarTask.resources = sidecarResources;
        };

        checks = [{
          expose = true;
          name = "mealie-health";
          port = "health";
          type = "http";
          path = "/api/app/about";
          interval = 30 * time.second;
          timeout = 5 * time.second;
        }];

        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.mealie.entrypoints=web,websecure,cloudflared"
          "traefik.http.routers.mealie.rule=Host(`mealie.tfk.nd`) || Host(`mealie.dcotta.com`)"
          "traefik.http.routers.mealie.tls=true"
        ];
      };

      task."rclone" = {
        lifecycle = {
          hook = "prestart";
          sidecar = true;
        };
        driver = "docker";
        vault = { };
        config = {
          image = "rclone/rclone:${rcloneVersion}";
          privileged = true;
          entrypoint = [ "/bin/sh" "-c" ];
          args = [
            ''
              umount -l ${b2Dir} 2>/dev/null
              mkdir -p ${b2Dir}
              exec rclone mount "b2:$BUCKET/data" ${b2Dir} \
                --allow-other \
                --uid 911 --gid 911 --umask 002 \
                --vfs-cache-mode writes \
                --cache-dir /local/rclone-cache \
                --dir-cache-time 1m \
                --b2-hard-delete
            ''
          ];
          mounts = [{
            type = "bind";
            source = "../alloc/data";
            target = sharedRoot;
            readonly = false;
            bind_options.propagation = "rshared";
          }];
        };
        resources = {
          cpu = 100;
          memory = 128;
          memoryMax = 512;
        };
        templates = [{
          destination = "secrets/rclone.env";
          changeMode = "restart";
          env = true;
          data = ''
            {{ with secret "secret/data/nomad/job/mealie/b2" }}
            RCLONE_CONFIG_B2_TYPE=b2
            RCLONE_CONFIG_B2_ACCOUNT={{ .Data.data.keyID }}
            RCLONE_CONFIG_B2_KEY={{ .Data.data.applicationKey }}
            BUCKET={{ .Data.data.bucket }}
            {{ end }}
          '';
        }];
      };

      task."litestream-restore" = {
        lifecycle.hook = "prestart";
        driver = "docker";
        vault = { };
        config = {
          image = "litestream/litestream:${litestreamVersion}";
          entrypoint = [ "/bin/sh" "-c" ];
          args = [ "mkdir -p ${dataDir} && exec litestream restore -config /secrets/litestream.yml -if-db-not-exists -if-replica-exists ${dbPath}" ];
        };
        resources = litestreamResources;
        templates = [ litestreamConfig ];
      };

      task."litestream" = {
        lifecycle = {
          hook = "poststart";
          sidecar = true;
        };
        driver = "docker";
        vault = { };
        config = {
          image = "litestream/litestream:${litestreamVersion}";
          entrypoint = [ "/bin/sh" "-c" ];
          args = [ "until [ -f ${dbPath} ]; do sleep 1; done; exec litestream replicate -config /secrets/litestream.yml" ];
        };
        resources = litestreamResources;
        templates = [ litestreamConfig ];
      };

      task."mealie" = {
        driver = "docker";
        config = {
          image = "ghcr.io/mealie-recipes/mealie:${version}";
          entrypoint = [ "/bin/sh" "/local/start.sh" ];
          mounts = [{
            type = "bind";
            source = "../alloc/data";
            target = sharedRoot;
            readonly = false;
            bind_options.propagation = "rslave";
          }];
        };
        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = mem * 2;
        };

        env = {
          DATA_DIR = dataDir;
          BASE_URL = "https://mealie.dcotta.com";
          ALLOW_SIGNUP = "false";
        };

        templates = [{
          destination = "local/start.sh";
          changeMode = "restart";
          # secrets are generated once and kept on B2, then copied locally because mealie
          # replaces them via rename, which would clobber a symlink
          data = ''
            set -e
            until grep -q ' ${b2Dir} fuse' /proc/mounts; do sleep 1; done
            mkdir -p ${dataDir}
            for d in ${toString b2Subdirs}; do
              mkdir -p ${b2Dir}/$d
              ln -sfn ${b2Dir}/$d ${dataDir}/$d
            done
            for s in ${toString secretFiles}; do
              [ -s ${b2Dir}/$s ] || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > ${b2Dir}/$s
              cp ${b2Dir}/$s ${dataDir}/$s
            done
            chown -R 911:911 ${dataDir}
            exec /app/run.sh
          '';
        }];
      };
    };
  };
}
