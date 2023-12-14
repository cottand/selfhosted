
# sets up a Nomad node with options to run specifically in the mesh.dcotta.eu fleet
# binds specifically to wg-mesh interface

# TODO add assertion for checking for wg-mesh

{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.nomadNode;
  seaweedVolumePath = "/seaweed.d/volume";
in
{

  ## interface
  options = {
    nomadNode = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      enableSeaweedFsVolume = mkOption {
        type = types.bool;
        description = "Whether to make this nomad client capable of hosting a SeaweedFS volume";
      };

      extraSettingsText = mkOption {
        type = types.str;
        default = "";
        description = "Extra settings as HCL";
        example = ''
          server {
              enabled = false
              bootstrap_expect = 3
              server_join {
                  retry_join = [ "10.10.0.1", "10.10.2.1" ]
                  retry_max = 3
                  retry_interval = "15s"
              }
          }
        '';
      };
    };
  };
  ## implementation
  config = mkIf cfg.enable {
    environment.etc = {
      "nomad/config/client.hcl".text = (builtins.readFile ./defaultNomadConfig/client.hcl);
      "nomad/config/server.hcl".text = (builtins.readFile ./defaultNomadConfig/server.hcl);
      "nomad/config/extraSettings.hcl".text = cfg.extraSettingsText;
    };


    systemd.tmpfiles.rules = mkIf cfg.enableSeaweedFsVolume [
      "d ${seaweedVolumePath} 1777 root root -"
    ];

    systemd.services.nomad.restartTriggers = [
      config.environment.etc."nomad/config/client.hcl".text
      config.environment.etc."nomad/config/server.hcl".text
      config.environment.etc."nomad/config/extraSettings.hcl".text
    ];
    systemd.services.nomad.after = [
      "wg-quick-wg-mesh.service"
    ];


    networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
    services.nomad = {
      enable = true;
      package = pkgs.nomad_1_7;
      enableDocker = true;
      dropPrivileges = false;
      extraPackages = with pkgs; [ cni-plugins getent wget curl ];
      extraSettingsPlugins = [ pkgs.nomad-driver-podman ];
      extraSettingsPaths = [
        "/etc/nomad/config/server.hcl"
        "/etc/nomad/config/client.hcl"
        "/etc/nomad/config/extraSettings.hcl"
      ];
      settings = {
        client = {
          cni_path = "${pkgs.cni-plugins}/bin";

          host_volume = mkIf cfg.enableSeaweedFsVolume {
            "seaweedfs-volume" = {
              path = "${seaweedVolumePath}";
              read_only = false;
            };
          };

          meta = mkIf cfg.enableSeaweedFsVolume {
            seaweedfs_volume = true;
          };
        };
      };
    };
  };
}
