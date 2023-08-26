{ config, pkgs, ... }:
{
  environment.etc = {
    "nomad/config/client.hcl" = {
      text = (builtins.readFile ./client.hcl);
    };
    "nomad/config/server.hcl" = {
      text = (builtins.readFile ./server.hcl);
    };
  };
  systemd.tmpfiles.rules = [
    "d /seaweed.d/volume 1777 root root -"
    "d /seaweed.d/filer 1777 root root -"
    "d /grafana.d/ 1777 root root -"
  ];
  services.nomad = {
    package = pkgs.nomad_1_6;

    enable = true;
    enableDocker = true;
    dropPrivileges = false;
    extraPackages = with pkgs; [ cni-plugins getent ];
    extraSettingsPlugins = [ pkgs.nomad-driver-podman ];
    extraSettingsPaths = [
      "/etc/nomad/config/server.hcl"
      "/etc/nomad/config/client.hcl"
    ];
    settings = {
      client = {
        cni_path = "${pkgs.cni-plugins}/bin";
      };
    };
  };

   environment.systemPackages = with pkgs; [ dmidecode ];
  
}
