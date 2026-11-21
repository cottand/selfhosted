{ util, time, ... }:
let
  name = "go2rtc";
  image = "ghcr.io/alexxit/go2rtc";
  version = "1.9.15";
  cpu = 3000;
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

  mediamtx = {
    image = "bluenviron/mediamtx";
    version = "1.21.4";
    cpu = 900;
    mem = 512;
    ports = {
      rtsp = 8554;
      hls = 8888;
      webrtc = 8889;
      ice = 8189;
      api = 9997;
      metrics = 9998;
    };
  };

  # plain service outside of the mesh, so WebRTC peers can reach go2rtc directly
  apiService = {
    port = "web";
    checks = [ ];
    tags = [ "traefik.enable=false" ];
  };

  mkTask =
    { name
    , device
    , connString ? "ffmpeg:device?video=/dev/video0&input_format=mjpeg&video_size=1024x576&framerate=30#video=h264"
    , ...
    }: {
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
          {
            type = "bind";
            source = "/dev/video2";
            target = "/dev/video2";
            readonly = false;
          }
          {
            type = "bind";
            source = "/dev/video3";
            target = "/dev/video3";
            readonly = false;
          }
          {
            type = "bind";
            source = "/dev/video4";
            target = "/dev/video4";
            readonly = false;
          }
          {
            type = "bind";
            source = "/dev/video5";
            target = "/dev/video5";
            readonly = false;
          }
        ];
      };

      resources = {
        cpu = cpu;
        memory = mem;
        memoryMax = builtins.ceil (2 * mem);

        # Webcam C270 (Logitech, Inc.) - same device as motioneye
        #          device."046d/usb/0825" = { };
        # Webcam Brio 100
        #          device."046d/usb/094c" = { };
        device.${device} = { };
      };

      vault = { };

      templates = [
        {
          destination = "local/go2rtc.yaml";
          changeMode = "restart";
          data = ''
            api:
              listen: ":${toString ports.web}"

            rtsp:
              listen: ":${toString ports.rtsp}"
              #default_query: "video=h264"

            webrtc:
              listen: ":${toString ports.webrtc}"
              candidates:
                - {{ env "NOMAD_HOST_IP_webrtc" }}:{{ env "NOMAD_HOST_PORT_webrtc" }}

            streams:
              webcam:
                 # we have 1024x576, 1280x960...
                - ${connString}
                #??- ffmpeg:device?video=/dev/video0&input_format=yuyv422&video_size=1024x576&framerate=30
                #- v4l2:device?video=/dev/video0&input_format=yuyv422&video_size=1024x576&framerate=30
                #- v4l2:device?video=/dev/video0&input_format=mjpeg&video_size=1280x960&framerate=30
              webcam_h265:
                - ffmpeg:rtsp://localhost:${toString ports.rtsp}/webcam#video=h264#drawtext=x=2:y=2:fontsize=12:fontcolor=white:box=1:boxcolor=black

            ffmpeg:
              global: "-hide_banner -loglevel warning"

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
in
{
  job."${name}" = {
    group."${name}-tall" = {
      count = 1;
      network = {
        mode = "bridge";
        port."rtsp" = {
          static = ports.rtsp;
          hostNetwork = "ts";
        };
        port."web" = {
          to = ports.web;
          hostNetwork = "ts";
        };
        port."webrtc" = {
          to = ports.webrtc;
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
            "traefik.http.routers.${fishRouter}.entrypoints=web, web_public, websecure, websecure_public, cloudflared"
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

      service."${name}-tall-api" = apiService;

      task."${name}-tall" = mkTask {
        name = "${name}-tall";
        device = "046d/usb/094c";
        connString = "ffmpeg:device?video=/dev/video0&input_format=mjpeg&video_size=1920x1080&framerate=30#video=h264";
      };
    };
    group."${name}-short" = {
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
        port."webrtc" = {
          to = ports.webrtc;
          hostNetwork = "ts";
        };
        #        port."rtsp" = {
        #          static = ports.rtsp;
        #          hostNetwork = "ts";
        #        };
        port."metrics".hostNetwork = "ts";
      };

      service."${name}-short-api" = apiService;

      task."${name}-short" = mkTask {
        name = "${name}-short";
        device = "046d/usb/0825";
        connString = "ffmpeg:device?video=/dev/video4&input_format=mjpeg&video_size=1280x960&framerate=30#video=h264";
      };
    };

    group."mediamtx" = {
      count = 1;
      network = {
        mode = "bridge";
        port."rtsp" = {
          to = mediamtx.ports.rtsp;
          hostNetwork = "ts";
        };
        port."hls" = {
          to = mediamtx.ports.hls;
          hostNetwork = "ts";
        };
        port."webrtc" = {
          to = mediamtx.ports.webrtc;
          hostNetwork = "ts";
        };
        # ICE candidates advertise this port, so host and container ports must match
        port."ice" = {
          static = mediamtx.ports.ice;
          hostNetwork = "ts";
        };
        port."api" = {
          to = mediamtx.ports.api;
          hostNetwork = "ts";
        };
        port."metrics" = {
          to = mediamtx.ports.metrics;
          hostNetwork = "ts";
        };
      };

      service."mediamtx-rtsp" = {
        port = "rtsp";
        checks = [ ];
        tags = [ "traefik.enable=false" ];
      };

      service."mediamtx-webrtc" = {
        port = "webrtc";
        checks = [ ];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=false"
          "traefik.http.routers.mediamtx-webrtc.entrypoints=web,websecure"
          "traefik.http.routers.mediamtx-webrtc.tls=true"
        ];
      };

      service."mediamtx-hls" = {
        port = "hls";
        checks = [ ];
        tags = [
          "traefik.enable=true"
          "traefik.consulcatalog.connect=false"
          "traefik.http.routers.mediamtx-hls.entrypoints=web,websecure"
          "traefik.http.routers.mediamtx-hls.tls=true"
        ];
      };

      service."mediamtx-metrics" = rec {
        port = "metrics";
        meta = {
          metrics_port = "\${NOMAD_HOST_PORT_metrics}";
          metrics_path = "/metrics";
        };
        checks = [
#          {
#            name = "metrics";
#            type = "http";
#            path = meta.metrics_path;
#            interval = 10 * time.second;
#            timeout = 3 * time.second;
#          }
        ];
        tags = [ "traefik.enable=false" ];
      };

      task."mediamtx" = {
        driver = "docker";

        config = {
          image = "${mediamtx.image}:${mediamtx.version}";
          ports = [ "rtsp" "hls" "webrtc" "ice" "api" "metrics" ];
          volumes = [ "local/mediamtx.yml:/mediamtx.yml" ];
        };

        resources = {
          cpu = mediamtx.cpu;
          memory = mediamtx.mem;
          memoryMax = builtins.ceil (2 * mediamtx.mem);
        };

        templates = [
          {
            destination = "local/mediamtx.yml";
            changeMode = "restart";
            data =
              let
                services = { tall = "${name}-tall-api"; short = "${name}-short-api"; };
                anyService = builtins.concatStringsSep " " (map (s: ''(service "${s}")'') (builtins.attrValues services));
                # only rendered while go2rtc has a registered instance, so mediamtx starts without it
                mkPath = path: service: ''
                  {{- with service "${service}" }}{{ with index . 0 }}
                    ${path}:
                      source: whep://{{ .Address }}:{{ .Port }}/api/webrtc?src=webcam
                      sourceOnDemand: yes
                  {{- end }}{{ end }}
                '';
              in
              ''
                logLevel: info

                api: yes
                apiAddress: :${toString mediamtx.ports.api}

                metrics: yes
                metricsAddress: :${toString mediamtx.ports.metrics}

                rtsp: yes
                rtspAddress: :${toString mediamtx.ports.rtsp}
                rtspTransports: [ tcp ]

                rtmp: no
                srt: no

                hls: yes
                hlsAddress: :${toString mediamtx.ports.hls}

                webrtc: yes
                webrtcAddress: :${toString mediamtx.ports.webrtc}
                webrtcLocalUDPAddress: :${toString mediamtx.ports.ice}
                webrtcLocalTCPAddress: ""
                webrtcIPsFromInterfaces: no
                webrtcAdditionalHosts:
                  - {{ env "NOMAD_HOST_IP_ice" }}

                {{ if or ${anyService} }}paths:{{ else }}paths: {}{{ end }}
                ${builtins.concatStringsSep "" (builtins.attrValues (builtins.mapAttrs mkPath services))}
              '';
          }
        ];
      };
    };
  };
}
