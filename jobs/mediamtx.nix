{ util, time, ... }:
let
  name = "mediamtx";
  image = "bluenviron/mediamtx";
  version = "latest-ffmpeg";
  cpu = 2000;
  mem = 512;
  ports = {
    rtmp = 1935;
    rtsp = 8554;
    webrtc = 8889;
    api = 9997;
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
        port."rtmp" = {
          static = ports.rtmp;
          hostNetwork = "ts";
        };
        port."webrtc" = {
          static = ports.webrtc;
          hostNetwork = "ts";
        };
        port."api" = {
          static = ports.api;
          hostNetwork = "ts";
        };
        port."metrics".hostNetwork = "ts";
      };

      service."${name}-api" = rec {
        connect.sidecarService = {
          proxy = {
            upstreams = [{ destinationName = "tempo-otlp-grpc-mesh"; localBindPort = otlpPort; }];

            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-rtmp";
              otlpUpstreamPort = otlpPort;
              protocol = "tcp";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.api;
        checks = [ ];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}-api.entrypoints=web,websecure"
          "traefik.http.routers.${name}-api.tls=true"
        ];
      };
      service."${name}-webrtc" = rec {
        connect.sidecarService = {
          proxy = {
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-webrtc";
              otlpUpstreamPort = otlpPort;
              protocol = "http";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.webrtc;
        checks = [
        ];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}-webrtc.entrypoints=web,websecure"
          "traefik.http.routers.${name}-webrtc.tls=true"
        ];
      };
      service."${name}-rtmp" = rec {
        connect.sidecarService = {
          proxy = {
            config = util.mkEnvoyProxyConfig {
              otlpService = "proxy-${name}-rtmp";
              otlpUpstreamPort = otlpPort;
              protocol = "tcp";
            };
          };
        };
        connect.sidecarTask.resources = sidecarResources;
        port = toString ports.webrtc;
        checks = [
        ];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=true"
          "traefik.http.routers.${name}-rtmp.entrypoints=web,websecure"
          "traefik.http.routers.${name}-rtmp.tls=true"
        ];
      };

      task."${name}" = {
        driver = "docker";
        vault = { };

        config = {
          image = "${image}:${version}";
          privileged = true;
          ports = [ "rtmp" "webrtc" "api" ];
          volumes=["local/mediamtx.yml:/mediamtx.yml"];
          mounts = [
#            {
#              type = "bind";
#              source = "/dev/video0";
#              target = "/dev/video0";
#              readonly = false;
#            }
#            {
#              type = "bind";
#              source = "/dev/video1";
#              target = "/dev/video1";
#              readonly = false;
#            }
          ];
        };

        resources = {
          cpu = cpu;
          memory = mem;
          memoryMax = builtins.ceil (2 * mem);

          # Webcam C270 (Logitech, Inc.) - same device as motioneye
          #device."046d/usb/0825" = { };
        };

        vault = { };

        templates = [{
          destination = "local/mediamtx.yml";
          changeMode = "restart";
          data = ''
            # Global settings
            logLevel: debug
            logDestinations: [stdout]

            # API settings
            api: yes
            apiAddress: localhost:${toString ports.api}

            # RTMP settings
            rtmp: yes
            rtmpAddress: localhost:${toString ports.rtmp}

            rtspAddress: localhost:${toString ports.rtsp}

            # WebRTC settings
            webrtc: yes
            webrtcAddress: localhost:${toString ports.webrtc}
            webrtcEncryption: no
            webrtcAllowOrigin: "*"
            webrtcTrustedProxies: []
            webrtcLocalUDPAddress: localhost:8189

            # Path settings
            paths:
              # USB camera stream - main
              webcam:
                source: publisher
                sourceProtocol: automatic
                #runOnInit: ffmpeg -f v4l2 -i /dev/video0 -c:v libx264 -preset veryfast -maxrate 3000k -bufsize 6000k -f rtsp rtsp://localhost:${toString ports.rtsp}/cam
                #runOnInit: ffmpeg -i https://motioneye-stream.tfk.nd -c:v libx264 -f flv rtmp://localhost:${toString ports.rtmp}/cam
                #runOnInit: ffmpeg -f v4l2 -input_format mjpeg -i /dev/video0 -c:v libx264 -pix_fmt yuv420p -preset ultrafast -b:v 600k -f flv rtmp://localhost:${toString ports.rtmp}/cam
                #runOnInit: ffmpeg -f v4l2 -input_format mjpeg -i /dev/video0 -c:v libx264 -pix_fmt yuv420p -preset ultrafast -b:v 600k -f flv    rtmp://localhost:${toString ports.rtmp}/cam
                #runOnInit: ffmpeg -f v4l2 -input_format mjpeg -i /dev/video0 -c:v libx264 -preset ultrafast -f flv rtmp://localhost:${toString ports.rtmp}/cam
                runOnInitRestart: yes
                #runOnReady: ffmpeg -re -i rtmp://localhost:${toString ports.rtmp}/cam -c copy -f flv rtmp://a.rtmp.youtube.com/live2/{{ with secret "secret/data/nomad/job/mediamtx/youtube" }}{{ .Data.data.key }}{{ end }}
          '';
        }];

        env = {
          MTX_CONFPATH = "local/mediamtx.yml";
          MTX_WEBRTCADDITIONALHOSTS="mediamtx-webrtc.tfk.nd";
        };
      };
    };
  };
}
