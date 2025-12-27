{ config, ... }:
let
  lib = (import ./lib) { };
in
{
  imports = [
    ./modules
    ./whoami.nix
    ./filestash.nix
    ./web-portfolio.nix
    ./attic.nix
    ./traefik/job.nix
    ./roach.nix
    ./immich/immich.nix
    ./monitoring/grafana/job.nix
    ./monitoring/vector.nix
    ./monitoring/tempo.nix
    ./monitoring/loki.nix
    ./seaweed/master.nix
    ./seaweed/filer.nix
    ./seaweed/volume.nix
    ./ente.nix
    ./digitemp.nix
    ./shelly-exporter.nix
    ./motioneye.nix
    ./mediamtx.nix
    ./go2rtc.nix
  ];
}
