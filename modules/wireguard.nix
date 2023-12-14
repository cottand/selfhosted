# returns a module
{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.custom.wireguard;
  # makeModule = interface: confPath: port: {
  #   # see https://colmena.cli.rs/unstable/features/keys.html
  #   deployment.keys."${interface}.conf" = {
  #     text = (builtins.readFile confPath);

  #     destDir = "/etc/wireguard";

  #     uploadAt = "pre-activation";
  #   };
  #   networking = {
  #     wg-quick.interfaces.${interface}.configFile = "/etc/wireguard/${interface}.conf";
  #     firewall.trustedInterfaces = [ interface ];
  #     firewall.allowedUDPPorts = [ port ];
  #   };

  #   systemd.services."wg-quick-${interface}".partOf = [ "${interface}.conf-key.service" ];
  # };
  interfaceOpts = {
    options = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = "Whether to enable the interface";
      };
      confPath = mkOption {
        type = types.str;
      };

      port = mkOption {
        type = types.int;
      };
    };
  };
in
{
  options.custom.wireguard = mkOption {
    description = "Creates a WG interface with the name=<name>";
    default = { };
    type = types.attrsOf (types.submodule interfaceOpts);
  };


  # https://gist.github.com/udf/4d9301bdc02ab38439fd64fbda06ea43#planet-status-h4xed
  # doing this top-level is a nightmare
  config = {
    deployment.keys = flip concatMapAttrs cfg
      (interface: opts: mkIf opts.enable {
        "${interface}.conf" = {
          keyFile = opts.confPath;
          # text = (builtins.readFile opts.confPath);

          destDir = "/etc/wireguard";

          uploadAt = "pre-activation";
        };
      });


    networking = flip concatMapAttrs cfg (interface: { confPath, port, enable, ... }: mkIf enable {
      wg-quick.interfaces.${interface}.configFile = "/etc/wireguard/${interface}.conf";
      firewall.trustedInterfaces = [ interface ];
      firewall.allowedUDPPorts = [ port ];
    });

    systemd = flip concatMapAttrs cfg (interface: { enable, ... }: mkIf enable {
      services."wg-quick-${interface}".partOf = [ "${interface}.conf-key.service" ];
    });
  };
}


# TODO fix wg-ci