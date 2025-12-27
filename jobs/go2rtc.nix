{ util, time, ... }:
let
  name = "go2rtc";
  image = "ghcr.io/alexxit/go2rtc";
  version = "1.9.13";
  cpu = 2500;
  mem = 512;
  ports = {
    web = 1984;
    rtsp = 8554;
    webrtc = 8555;
  };
  sidecarResources = with builtins; mapAttrs (_: ceil) {
    cpu = 0.20 * cpu;
    memory = 0.25 * mem;
    memoryMax = 0.25 * mem + 100;
  };
  otlpPort = 9001;
in
{
  job."${name}" = {
    group."${name}" = {
      count = 1;
      network = {
        mode = "bridge";
        reservedPorts."rtsp" = {
          static = ports.rtsp;
          hostNetwork = "ts";
        };
        port."web" = {
          to = ports.web;
          hostNetwork = "ts";
        };
#        port."rtsp" = {
#          static = ports.rtsp;
#          hostNetwork = "ts";
#        };
        port."metrics".hostNetwork = "ts";
      };

      service."${name}-web" = rec {
        connect.sidecarService = {
          proxy = {
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-web";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.web;
        checks = [ ];
        tags =
          let
            fishRouter = "${name}-fish-dcotta-com-public";
            redirectMiddleware = "${fishRouter}-redirect";
          in
          [
            "traefik.enable=true"
            "traefik.consulcatalog.connect=true"
            "traefik.http.routers.${name}-web.entrypoints=web,websecure"
            "traefik.http.routers.${name}-web.tls=true"


            # only match rtc stream for webcam
            (
              "traefik.http.routers.${fishRouter}.rule=Host(`fish.dcotta.com`) || Host(`fish.dcotta.com`) && (" +
              "   (Query(`src`, `webcam`) && PathPrefix(`/stream.html`))" +
              "|| (Query(`src`, `webcam`) && PathPrefix(`/api/ws`)     )" +
              "||  PathPrefix(`/video-stream.js`)" +
              "||  PathPrefix(`/video-rtc.js`)" +
              ")"
            )
            "traefik.http.routers.${fishRouter}.entrypoints=web, web_public, websecure, websecure_public"
            "traefik.http.routers.${fishRouter}.tls=true"
            "traefik.http.routers.${fishRouter}.middlewares=${redirectMiddleware}"

            # redirect fish.dcotta.com -> fish.dcotta.com/stream.html?src=webcam
            "traefik.http.middlewares.${redirectMiddleware}.redirectregex.regex=fish.dcotta.com/$"
            "traefik.http.middlewares.${redirectMiddleware}.redirectregex.replacement=fish.dcotta.com/stream.html?src=webcam"
            "traefik.http.middlewares.${redirectMiddleware}.redirectregex.permanent=true"
          ];
      };

      # traefik struggles to http proxy
      #      service."${name}-rtsp" = {
      #        port = toString ports.rtsp;
      #        checks = [ ];
      #        tags = [
      #          "traefik.enable=true"
      #          "traefik.consulcatalog.connect=false" # do not go via proxy
      #          "traefik.tcp.routers.${name}-rtsp.entrypoints=web,websecure"
      #          # "traefik.tcp.routers.${name}-rtsp.tls=false"
      #          "traefik.tcp.routers.${name}-rtsp.rule=HostSNI(`${name}-rtsp.tfk.nd`)"
      #          "traefik.tcp.routers.${name}-rtsp.tls=true"
      #
      #        ];
      #      };

      task."${name}" = {
        driver = "docker";
        vault = { };

        config = {
          image = "${image}:${version}";
          privileged = true;
          ports = [ "web" "webrtc" ];
          volumes = [ "local/go2rtc.yaml:/config/go2rtc.yaml" ];
          mounts = [
            {
              type = "bind";
              source = "/dev/video0";
              target = "/dev/video0";
              readonly = false;
            }
            {
              type = "bind";
              source = "/dev/video1";
              target = "/dev/video1";
              readonly = false;
            }
          ];
        };

        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);

          # Webcam C270 (Logitech, Inc.) - same device as motioneye
          device."046d/usb/0825" = { };
        };

        vault = { };

        templates = [
          {
            destination = "local/go2rtc.yaml";
            changeMode = "restart";
            data = ''
              api:
                listen: "localhost:${toString ports.web}"

              rtsp:
                listen: ":${toString ports.rtsp}"
                default_query: "video=h264"

              webrtc:
                listen: "localhost:${toString ports.webrtc}"

              streams:
                webcam:
                  - ffmpeg:device?video=/dev/video0&video_size=1280x960&framerate=30#video=h264
                  - v4l2:device?video=/dev/video0&input_format=yuyv422&video_size=1280x960&framerate=30

                  #- v4l2:device?video=/dev/video0&input_format=mjpeg&video_size=1280x960&framerate=30

              ffmpeg:
                global: "-hide_banner -loglevel error"

              publish:
                webcam:
                  #- rtmps://a.rtmp.youtube.com/live2/{{ with secret "secret/data/nomad/job/go2rtc/youtube" }}{{ .Data.data.key }}{{ end }}
                  #- rtmps://mediamtx-rtmp.tfk.nd/cam/
            '';
          }
        ];

        env = {
          GO2RTC_CONFIG = "/config/go2rtc.yaml";
        };
      };
    };
  };
}
