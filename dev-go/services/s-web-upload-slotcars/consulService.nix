let
  name = "s-web-upload-slotcars";
  sidecarResources = {
    cpu = 20;
    memory = 30;
    memoryMax = 120;
  };
in
{ util, ... }: {
  job."services-go".group."services-go".service.${name} = {
    inherit name;
    connect = {
      sidecarService.proxy = {
        config = util.mkEnvoyProxyConfig {
          otlpService = "proxy-${name}-http";
          otlpUpstreamPort = 9001;
          # uploads go on to GitHub before responding
          extra.local_request_timeout_ms = 60 * 1000;
          extra.protocol = "http";
        };
      };
      sidecarTask.resources = sidecarResources;
    };
    port = "7005";
    tags = [
      "traefik.enable=true"
      "traefik.consulcatalog.connect=true"
      "traefik.http.routers.${name}.tls=true"
      "traefik.http.routers.${name}.entrypoints=web, websecure"

      "traefik.http.routers.${name}-pub.entrypoints=cloudflared"
      "traefik.http.routers.${name}-pub.rule=Host(`upload-slotcars.dcotta.com`)"
      "traefik.http.routers.${name}-pub.tls=true"

      "traefik.http.middlewares.${name}-header.headers.customresponseheaders.X-dcotta-com-svc=${name}"
    ];
  };
}
