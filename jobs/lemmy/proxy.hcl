
job "lemmy-proxy" {
  update {
    max_parallel = 1
    stagger      = "10s"
  }
  datacenters = ["dc1"]
  type        = "service"
  group "proxy" {
    network {
      mode = "bridge"
      port "http" {
        host_network = "wg-mesh"
        to           = 80
      }
    }

    task "lemmy-proxy" {
      service {
        name     = "lemmy-proxy"
        provider = "nomad"
        port     = "http"
        tags = [
          "traefik.enable=true",
          # for some reason only when there is a longer hostname this works
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`r.dcotta.eu`) || Host(`lemmy.dcotta.eu`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure_public,websecure,web_public,web",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls.certresolver=lets-encrypt",
        ]
        check {
          name     = "alive"
          type     = "tcp"
          interval = "20s"
          timeout  = "2s"
          check_restart {
            limit           = 3
            grace           = "10s"
            ignore_warnings = false
          }
        }
      }

      driver = "docker"

      config {
        image = "nginx:alpine3.17-slim"
        ports = ["http"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf",
        ]
      }

      template {
        destination = "local/nginx.conf"
        change_mode = "restart"
        data        = <<EOF
worker_processes 1;
events {
    worker_connections 1024;
}

http {
    upstream lemmy {
        {{ range nomadService "lemmy" }}
        server "{{ .Address }}:{{ .Port }}";
        {{ else }}server 127.0.0.1:65535; # force a 502
        {{ end }}
    }
    upstream lemmy-ui {
        {{ range nomadService "lemmy-ui" }}
        server "{{ .Address }}:{{ .Port }}";
        {{ else }}server 127.0.0.1:65535; # force a 502
        {{ end }}
    }

    server {
        # this is the port inside docker, not the public one yet
        listen 80;
        # change if needed, this is facing the public web
        server_name r.dcotta.eu;
        server_tokens off;

        gzip on;
        gzip_types text/css application/javascript image/svg+xml;
        gzip_vary on;

        # Upload limit, relevant for pictrs
        client_max_body_size 20M;

        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        # frontend general requests
        location / {

            # distinguish between ui requests and backend
            # don't change lemmy-ui or lemmy here, they refer to the upstream definitions on top
            set $proxpass "http://lemmy-ui";

            if ($http_accept ~ "^application/.*$") {
              set $proxpass "http://lemmy";
            }
            if ($request_method = POST) {
              set $proxpass "http://lemmy";
            }
            proxy_pass $proxpass;

            rewrite ^(.+)/+$ $1 permanent;
            # Send actual client IP upstream
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # backend
        location ~ ^/(api|pictrs|feeds|nodeinfo|.well-known) {
            proxy_pass "http://lemmy";
            # proxy common stuff
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Send actual client IP upstream
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}

EOF

      }
    }
  }
}