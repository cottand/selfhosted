{ config, pkgs, ... }:
{
  # environment.etc = {
  #   "nomad/config/client.hcl" = {
  #     text = (builtins.readFile ./client.hcl);
  #   };
  # };
  # systemd.tmpfiles.rules = [
  #   "d /seaweed.d/volume 1777 root root -"
  # ];
  # services.nomad = {
  #   package = pkgs.nomad_1_6;
  #   enable = true;
  #   enableDocker = true;
  #   dropPrivileges = false;
  #   extraPackages = with pkgs; [ cni-plugins getent wget curl ];
  #   extraSettingsPlugins = [ pkgs.nomad-driver-podman ];
  #   extraSettingsPaths = [
  #     "/etc/nomad/config/client.hcl"
  #   ];
  #   settings = {
  #     client = {
  #       cni_path = "${pkgs.cni-plugins}/bin";
  #     };
  #   };
  # };
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      datacenter = "madrid-gormaz"
      client {
        meta {
          box = "bianco"
          name = "bianco"
        }
      }
    '';
  };
}
