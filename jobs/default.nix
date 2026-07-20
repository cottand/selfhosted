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
    ./immich/backup-db.nix
    ./monitoring/grafana/job.nix
    ./monitoring/vector.nix
    ./monitoring/tempo.nix
    ./monitoring/loki.nix
    ./seaweed/master.nix
    ./seaweed/filer.nix
    ./seaweed/volume.nix
    ./seaweed/backup.nix
#    ./seaweed/admin.nix
#    ./seaweed/worker.nix
    ./ente/ente.nix
    ./ente/backup-ente-db.nix
    ./digitemp.nix
    ./shelly-exporter.nix
    ./motioneye.nix
    ./mediamtx.nix
    ./go2rtc.nix
    ./comet.nix
    ./minecraft.nix
    ./mosquitto.nix
    ./papra.nix
  ];
}
