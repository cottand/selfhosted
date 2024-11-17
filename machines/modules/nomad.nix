{ name, pkgs, lib, config, ... }:
with lib;
let
  cfg = config.nomadNode;
  seaweedVolumePath = "/seaweed.d/volume";
  inherit (lib) types;
  volumeOptsType = { lib, name, config, ... }: {
    options = {
      name = lib.mkOption {
        description = "Name of the volume";
        default = name;
        type = types.str;
        internal = true;
      };

      hostPath = mkOption {
        type = types.str;
        example = "/roach.d";
      };

      readOnly = mkOption {
        type = types.bool;
      };
    };
  };
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

      hostVolumes = mkOption {
        description = "Adds a host volume";
        default = { };
        type = types.attrsOf (types.submodule volumeOptsType);
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
                  retry_join = [  ]
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
    systemd.services.nomad.serviceConfig.Restart = lib.mkForce "always";
    environment.etc = {
      "nomad/config/client.hcl".text = (builtins.readFile ./defaultNomadConfig/client.hcl);
      "nomad/config/server.hcl".text = (builtins.readFile ./defaultNomadConfig/server.hcl);
      "nomad/config/extraSettings.hcl".text = cfg.extraSettingsText;

      # necessary in order to copy files over to etc/ssl/certs (not symlink) so that volumes can mount these dirs
      "ssl/certs/ca-certificates.crt".mode = "0644";
      "ssl/certs/ca-bundle.crt".mode = "0644";
      "pki/tls/certs/ca-bundle.crt".mode = "0644";
    };


    systemd.tmpfiles.rules =
      (map (vol: "d ${vol.hostPath} 1777 root root -") (builtins.attrValues cfg.hostVolumes))
      ++
      (if cfg.enableSeaweedFsVolume then [ "d ${seaweedVolumePath} 1777 root root -" ] else [ ]);

    systemd.services.nomad.restartTriggers = [
      config.environment.etc."nomad/config/client.hcl".text
      config.environment.etc."nomad/config/server.hcl".text
      config.environment.etc."nomad/config/extraSettings.hcl".text
    ];
    systemd.services.nomad.after = mkIf config.services.tailscale.enable [
      "tailscaled.service"
    ];

    systemd.services.nomad.wants = mkIf config.services.tailscale.enable [
      "tailscaled.service"
    ];

    vaultSecrets =
      let
        destDir = "/opt/nomad/tls";
        secretPath = "nomad/infra/tls";
      in
      {
        "nomad.crt.pem" = {
          inherit destDir secretPath;
          field = "cert";
        };
        "nomad.ca.pem" = {
          inherit destDir secretPath;
          field = "ca";
        };
        "nomad.key.rsa" = {
          inherit destDir secretPath;
          field = "private_key";
        };
      };

    networking.firewall.trustedInterfaces = [ "nomad" "docker0" ];
    services.nomad = {
      enable = true;
      package = pkgs.nomad_1_9;
      enableDocker = true;
      dropPrivileges = false;
      extraPackages = with pkgs; [ cni-plugins getent wget curl consul ];
      extraSettingsPlugins = [ pkgs.nomad-driver-podman ];
      extraSettingsPaths = [
        "/etc/nomad/config/server.hcl"
        "/etc/nomad/config/client.hcl"
        "/etc/nomad/config/extraSettings.hcl"
      ];
      settings = {
        client = {
          network_interface = config.services.tailscale.interfaceName;

          cni_path = "${pkgs.cni-plugins}/bin";

          host_volume =
            (builtins.mapAttrs (_: attrs: { path = attrs.hostPath; read_only = attrs.readOnly; }) cfg.hostVolumes)
            //
            (if cfg.enableSeaweedFsVolume then
              { "seaweedfs-volume" = { path = seaweedVolumePath; read_only = false; }; } else { });


          host_network =
            if config.services.tailscale.enable then {
              "ts" = {
                cidr = "100.64.0.0/10";
                reserved_ports = "${ toString config.services.tailscale.port },22";
              };
            } else { };

          meta = {
            box = name;
            name = name;
            seaweedfs_volume = cfg.enableSeaweedFsVolume;
          };
        };

        # Require TLS
        tls = {
          rpc_upgrade_mode = true;
          http = true;
          rpc = true;

          ca_file = config.vaultSecrets."nomad.ca.pem".path;
          cert_file = config.vaultSecrets."nomad.crt.pem".path;
          key_file = config.vaultSecrets."nomad.key.rsa".path;
          verify_https_client = false;

          verify_server_hostname = true;

        };
        consul =
          if config.consulNode.enable then {
            grpc_address = "127.0.0.1:${toString config.services.consul.extraConfig.ports.grpc_tls}";
            grpc_ca_file = config.vaultSecrets."consul.ca.pem".path;

            ca_file = config.vaultSecrets."consul.ca.pem".path;
            cert_file = config.vaultSecrets."consul.crt.pem".path;
            key_file = config.vaultSecrets."consul.key.rsa".path;
            address = "127.0.0.1:${toString config.services.consul.extraConfig.ports.https}";
            ssl = true;
            # share_ssl = true; default is true
          } else null;
      };
    };
  };
}
