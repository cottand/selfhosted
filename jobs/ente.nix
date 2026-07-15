{ util, time, defaults, ... }:
let
  resources = {
    cpu = 100;
    memory = 200;
    memoryMax = 500;
  };
  ports = {
    server = 8080;
    db = 5432;
    web = 3000;
    accounts = 3001;
    albums = 3002;
    auth = 3003;
    cast = 3004;
    share = 3005;
    embed = 3006;
    locker = 3009;
    memories = 3010;
  };
  sidecarResources = util.mkResourcesWithFactor 0.15 resources;
  otlpPort = 9001;
  bind = "127.0.0.1";

  # Web addresses
  enteWebUrl = "https://ente.tfk.nd";
  enteApiUrl = "https://ente-server.tfk.nd";
  version = "latest";

  webApps = [
    { name = "ente-photos"; port = ports.web; }
    { name = "ente-accounts"; port = ports.accounts; }
    { name = "ente-albums"; port = ports.albums; }
    { name = "ente-auth"; port = ports.auth; }
    { name = "ente-cast"; port = ports.cast; }
    { name = "ente-share"; port = ports.share; }
    { name = "ente-embed"; port = ports.embed; }
    { name = "ente-locker"; port = ports.locker; }
    { name = "ente-memories"; port = ports.memories; }
  ];

  mkWebService = app: {
    name = app.name;
    value = {
      port = toString app.port;
      connect = {
        sidecarService.proxy = {
          upstreams = [ ];
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-${app.name}-http";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
        sidecarTask.resources = sidecarResources;
      };

      checks = [{
        expose = true;
        name = "${app.name}-health";
        port = "hz-${app.name}";
        type = "http";
        path = "/";
        interval = 30 * time.second;
        timeout = 5 * time.second;
        task = "ente-web";
      }];

      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.${app.name}.entrypoints=web, websecure"
        "traefik.http.routers.${app.name}.tls=true"
        #        "traefik.http.routers.${app.name}.middlewares=${app.name}-headers"
        #
        #        "traefik.http.middlewares.${app.name}-headers.headers.accesscontrolallowmethods=GET,HEAD,POST,DELETE,OPTIONS,PUT"
        #        "traefik.http.middlewares.${app.name}-headers.headers.accesscontrolallowheaders=*"
        #        "traefik.http.middlewares.${app.name}-headers.headers.accesscontrolalloworiginlist=https://${app.name}.tfk.nd,${enteApiUrl}"
        #        "traefik.http.middlewares.${app.name}-headers.headers.accesscontrolmaxage=100"
        #        "traefik.http.middlewares.${app.name}-headers.headers.addvaryheader=true"
      ];
    };
  };

  webServices = builtins.listToAttrs (map mkWebService webApps);

  healthzPorts = builtins.listToAttrs (map
    (app: {
      name = "hz-${app.name}";
      value = { hostNetwork = "ts"; };
    })
    webApps);
in
{
  job."ente" = {
    type = "service";

    ui = {
      #      description = "";
      links = [
        { label = "Ente Web"; url = enteWebUrl; }
        { label = "Ente API"; url = enteApiUrl; }
      ];
    };

    group."ente" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port = healthzPorts;
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      update = {
        # TODO restore once we find a stable version
        #        maxParallel = 1;
        #        minHealthyTime = 30 * time.second;
        #        healthyDeadline = 5 * time.minute;
        #        autoRevert = true;
        #        autoPromote = true;
        #        canary = 1;
      };

      service = {
        # Ente Server (API)
        "ente-server" = {
          port = toString ports.server;
          connect = {
            sidecarService.proxy = {
              upstreams = [
                { destinationName = "ente-db"; localBindPort = ports.db; }
                #              { destinationName = "roach-db"; localBindPort = ports.db; }
                { destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }
              ];
              config = util.mkEnvoyProxyConfig {
                otlpService = "proxy-ente-server-http";
                otlpUpstreamPort = otlpPort;
                protocol = "http";
              };
            };
            sidecarTask.resources = sidecarResources;
          };

          checks = [
            # TODO health check
          ];

          tags = [
            "traefik.enable=true"
            "traefik.consulcatalog.connect=true"
            "traefik.http.routers.ente-api.middlewares=vpn-whitelist@file"
            "traefik.http.routers.ente-api.entrypoints=web, websecure"
            "traefik.http.routers.ente-api.tls=true"

            "traefik.http.routers.ente-api.middlewares=ente-api-headers"

            "traefik.http.middlewares.ente-api-headers.headers.accesscontrolallowmethods=GET,HEAD,POST,DELETE,OPTIONS,PUT"
            "traefik.http.middlewares.ente-api-headers.headers.accesscontrolallowheaders=*"
            "traefik.http.middlewares.ente-api-headers.headers.accesscontrolalloworiginlist=*"
            "traefik.http.middlewares.ente-api-headers.headers.accesscontrolmaxage=100"
            "traefik.http.middlewares.ente-api-headers.headers.addvaryheader=true"
          ];
        };
      } // webServices;

      # Ente Server Task
      task."ente-server" = {
        vault.env = true;
        driver = "docker";
        config = {
          #          image = "ghcr.io/cottand/ente-server:c119945faf6793f212becc2329266efce355c84f";
          image = "ghcr.io/ente/server:latest";

          volumes = [ "local/museum.yaml:/museum.yaml" ];
        };

        inherit resources;

        env = builtins.mapAttrs (_: toString) {
          HTTP_HOST = "0.0.0.0";
          HTTP_PORT = ports.server;
        };

        templates = [
          {
            destination = "local/museum.yaml";
            changeMode = "restart";
            data = ''
              db:
                host: "${bind}"
                port: "${toString ports.db}"
                name: ente
                user: ente
                password: "{{ with secret "secret/data/nomad/job/roach/users/ente" }}{{ .Data.data.password }}{{ end }}"
                #sslmode: verify-ca
                #extra: "sslsni=roach-db.tfk.nd sslrootcert=/secrets/ca.crt sslkey=/secrets/client.ente.key sslcert=/secrets/client.ente.crt"

              # Server configuration
              server:
                host: 0.0.0.0
                port: ${toString ports.server}

                {{ with secret "secret/data/nomad/job/ente/b2" }}

              s3:
                are_local_buckets: false
                # Only path-style URL works if disabling are_local_buckets with MinIO
                use_path_style_urls: true

                #!!!!
                #!!!! The bucket here needs to be CORS-configured
                #!!!! see https://ente.com/help/self-hosting/administration/object-storage#cors-cross-origin-resource-sharing
                #!!!!

                b2-eu-cen:
                  # are_local_buckets: true
                  # use_path_style_urls: true
                  key: {{ .Data.data.keyID }}
                  secret: {{ .Data.data.applicationKey }}
                  endpoint: s3.us-east-005.backblazeb2.com
                  region: us-east-005
                  bucket: cottand-ente-hot-primary
                wasabi-eu-central-2-v3:
                  # are_local_buckets: true
                  # use_path_style_urls: true
                  key: {{ .Data.data.keyID }}
                  secret: {{ .Data.data.applicationKey }}
                  endpoint: s3.us-east-005.backblazeb2.com
                  region: us-east-005
                  bucket: cottand-ente-cold
                  compliance: false
                scw-eu-fr-v3:
                  # are_local_buckets: true
                  # use_path_style_urls: true
                  key: {{ .Data.data.keyID }}
                  secret: {{ .Data.data.applicationKey }}
                  endpoint: s3.us-east-005.backblazeb2.com
                  region: us-east-005
                  bucket: cottand-ente-hot-secondary

                {{ end }}
                

              # JWT and encryption keys
              key:
                encryption: yvmG/RnzKrbCb9L3mgsmoxXr9H7i2Z4qlbT0mL3ln4w=
                hash: KXYiG07wC7GIgvCSdg+WmyWdXDAn6XKYJtp/wkEU7x573+byBRAYtpTP0wwvi8i/4l37uicX1dVTUzwH3sLZyw==
              jwt: i2DecQmfGreG6q1vBj5tCokhlN41gcfS2cjOs9Po-u8=

            '';
          }
          {
            destination = "/secrets/env";
            changeMode = "restart";
            env = true;
            data = ''
              PGSSLMODE=verify-ca
              PGSSLSNI=roach-db.tfk.nd
              PGSSLKEY=/secrets/client.ente.key
              PGSSLCERT=/secrets/client.ente.crt
              PGSSLROOTCERT=/secrets/ca.crt
            '';
          }
          #              {{ with secret "secret/data/nomad/job/ente" }}{{  .Data.data.jwt_secret }}{{ end }}
          #                {{ with secret "secret/data/nomad/job/ente" }}{{ .Data.data.encryption_key }}{{ end }}
          {
            destination = "/secrets/client.ente.key";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.key}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/client.ente.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.chain}}{{end}}
            '';
            perms = "0600";
          }
          {
            destination = "/secrets/ca.crt";
            changeMode = "restart";
            data = ''
              {{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.ca}}{{end}}
            '';
            perms = "0600";
          }
        ];
      };

      # Ente Web Task
      task."ente-web" = {
        driver = "docker";
        config = {
          image = "ghcr.io/ente/web:${version}";
          ports = [ "web" ];
        };

        inherit resources;

        env = builtins.mapAttrs (_: toString) {
          ENTE_API_ORIGIN = enteApiUrl;
        };
      };
    };

    group."ente-db" = {
      count = 1;
      network = {
        inherit (defaults) dns;
        mode = "bridge";
        port."healthz".hostNetwork = "ts";
      };
      volume."ente-db" = {
        name = "ente-db";
        type = "host";
        readOnly = false;
        source = "ente-db";
      };

      restart = {
        attempts = 3;
        interval = 10 * time.minute;
        delay = 15 * time.second;
        mode = "delay";
      };

      service."ente-db" = {
        port = toString ports.db;
        connect = {
          sidecarService.proxy = {
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-ente-db";
              otlpUpstreamPort = otlpPort;
              protocol = "tcp";
            };
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];
          };
          sidecarTask.resources = sidecarResources;
        };
        task = "postgres";
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.tcp.routers.ente-db.rule=HostSNI(`ente-db.traefik`) || HostSNI(`ente-db.tfk.nd`)"
          "traefik.tcp.routers.ente-db.entrypoints=sql"
          "traefik.tcp.routers.ente-db.tls=true"
        ];
        checks = [{
          name = "pg-ready";
          type = "script";
          command = "/bin/sh";
          args = [ "-c" "pg_isready -q -d ente -U ente" ];
          interval = 10 * time.second;
          timeout = 5 * time.second;
          task = "postgres";
        }];
      };

      task."postgres" = {
        vault.env = true;
        driver = "docker";
        config = {
          image = "postgres:15-trixie";
        };
        resources = {
          cpu = 200;
          memory = 256;
          memoryMax = 512;
        };
        env = {
          POSTGRES_DB = "ente";
          POSTGRES_USER = "ente";
        };
        #password: "{{ with secret "secret/data/nomad/job/roach/users/ente" }}{{ .Data.data.password }}{{ end }}"
        volumeMounts = [{
          volume = "ente-db";
          destination = "/var/lib/postgresql/data";
          readOnly = false;
        }];
        templates = [{
          destination = "/secrets/env";
          changeMode = "restart";
          data = ''
            POSTGRES_PASSWORD={{with secret "secret/data/nomad/job/roach/users/ente"}}{{.Data.data.password}}{{end}}
          '';
          env = true;
          perms = "0600";
        }];
      };
    };
  };
}
