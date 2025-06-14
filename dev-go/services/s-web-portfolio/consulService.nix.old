{ lib, sidecarResources, ... }:
let
  name = "s-web-portfolio";
in
{
  inherit name;
  connect = {
    sidecarService.proxy = {
      config = lib.mkEnvoyProxyConfig {
        otlpService = "proxy-${name}-http";
        otlpUpstreamPort = 9001;
        protocol = "http";
      };
    };
    sidecarTask.resources = sidecarResources;
  };
  port = "7001";
  tags = [
    "traefik.enable=true"
    "traefik.consulcatalog.connect=true"
    "traefik.http.routers.${name}.tls=true"
    "traefik.http.routers.${name}.entrypoints=web, web_public, websecure, websecure_public"
    "traefik.http.routers.${name}.middlewares=cloudflarewarp@file,${name}-stripprefix"
    "traefik.http.middlewares.${name}-stripprefix.stripprefix.prefixes=/${name}"
    "traefik.http.routers.${name}.rule=Host(`web.dcotta.com`) && PathPrefix(`/${name}`)"
    "traefik.http.routers.${name}.tls=true"


    "traefik.http.routers.${name}-redir.tls=true"
    "traefik.http.routers.${name}-redir.entrypoints=web, web_public, websecure, websecure_public"
    "traefik.http.routers.${name}-redir.middlewares=cloudflarewarp@file,${name}-redir"
    "traefik.http.routers.${name}-redir.rule=Host(`nico.dcotta.eu`)"

    "traefik.http.middlewares.${name}-redir.redirectregex.regex=nico.dcotta.eu/(.*)"
    "traefik.http.middlewares.${name}-redir.redirectregex.replacement=nico.dcotta.com/\${1}"
    "traefik.http.middlewares.${name}-redir.redirectregex.permanent=true"
    #
  ];
}
