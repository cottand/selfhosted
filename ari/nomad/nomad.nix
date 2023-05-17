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