let
  name = "s-web-github-webhook";
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
          protocol = "http";
        };
      };
      sidecarTask.resources = sidecarResources;
    };
    port = "7002";
    tags = [
      "traefik.enable=true"
      "traefik.consulcatalog.connect=true"
      "traefik.http.routers.${name}.tls=true"
      "traefik.http.routers.${name}.entrypoints=web, web_public, websecure, websecure_public"

      "traefik.http.routers.${name}.middlewares=${name}-stripprefix"

      "traefik.http.middlewares.${name}-stripprefix.stripprefix.prefixes=/${name}"
      "traefik.http.routers.${name}.rule=Host(`web.dcotta.com`) && PathPrefix(`/${name}`)"
      "traefik.http.routers.${name}.tls=true"
    ];
  };
}
