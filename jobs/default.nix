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
    ./seaweed/master.nix
  ];
}
