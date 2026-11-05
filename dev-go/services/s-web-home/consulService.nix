let
  name = "s-web-home";
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
          # /lights/events streams for as long as a page is open
          extra.local_request_timeout_ms = 0;
          extra.local_idle_timeout_ms = 0;
          extra.protocol = "http";
        };
      };
      sidecarTask.resources = sidecarResources;
    };
    port = "7004";
    tags = [
      "traefik.enable=true"
      "traefik.consulcatalog.connect=true"
      "traefik.http.routers.${name}.tls=true"
      "traefik.http.routers.${name}.entrypoints=web, websecure"

      "traefik.http.routers.${name}-pub.entrypoints=cloudflared"
      "traefik.http.routers.${name}-pub.rule=Host(`home.dcotta.com`)"
      "traefik.http.routers.${name}-pub.tls=true"

      "traefik.http.middlewares.${name}-header.headers.customresponseheaders.X-dcotta-com-svc=${name}"
    ];
  };
}
