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
  ];
  networking.firewall.interfaces.nomad = {
    allowedUDPPortRanges = [{
      from = 0;
      to = 65535;
    }];
    allowedTCPPortRanges = [{
      from = 0;
      to = 65535;
    }];
  };
  # allow all from nomad
  services.nomad = {
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
}
