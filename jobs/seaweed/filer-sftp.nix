{ util, time, defaults, ... }:
let
  ports.sftp = 12399;
  otlpPort = 9001;
  sidecarResources = util.mkResourcesWithFactor 0.2 {
    cpu = 100;
    memory = 200;
  };
in
{

  job."seaweed-filer".group."seaweed-filer" = {
    service."seaweed-sftp" = {
      connect.sidecarService = {
        proxy = {
          config = util.mkEnvoyProxyConfig {
            otlpService = "proxy-seaweed-filer-webdav";
            otlpUpstreamPort = otlpPort;
            protocol = "http";
          };
        };
      };
      connect.sidecarTask.resources = sidecarResources;
      port = toString ports.sftp;
      tags = [
        "traefik.enable=true"
        "traefik.consulcatalog.connect=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-webdav.entrypoints=web,websecure"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-webdav.tls=true"
        "traefik.http.routers.\${NOMAD_GROUP_NAME}-webdav.middlewares=mesh-whitelist@file"
      ];
    };

    task."seaweed-filer".config.args = [
      "-sftp"
      "-sftp.bannerMessage='DCotta.com Seaweed'"
      "-sftp.port=${toString ports.sftp}"
    ];
  };
}
