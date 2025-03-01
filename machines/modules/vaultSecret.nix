{ config, lib, ... }:
with lib; let
  cfg = config.vaultSecrets;
  secretOptsType = { lib, name, config, ... }:
    let
      inherit (lib) types;
    in
    {
      options = {
        # enable = mkOption {
        #   default = true;
        #   type = types.bool;
        #   description = "Whether to enable the secret";
        # };
        mount = mkOption {
          type = types.str;
          default = "secret";
        };

        name = lib.mkOption {
          description = "File name of the key";
          default = name;
          type = types.str;
          internal = true;
        };

        secretPath = mkOption {
          type = types.str;
          example = "nomad/infra/tls";
        };
        field = mkOption {
          type = types.str;
          example = "key";
        };
        destDir = mkOption {
          type = types.path;
        };
        path = mkOption {
          type = types.str;
          internal = true;
          default = "${config.destDir}/${config.name}";
        };
      };
    };
in
{

  options.vaultSecrets = mkOption {
    description = "Creates a deployments.keys with vault with filename name=<name>";
    default = { };
    type = types.attrsOf (types.submodule secretOptsType);
  };


  # implementation
  config = {
    deployment.keys = flip concatMapAttrs cfg
      (name: opts: {
        "${name}" = {
          destDir = opts.destDir;
          keyCommand = [ "vault" "kv" "get" "-mount=${opts.mount}" "-field=${opts.field}" opts.secretPath ];
          uploadAt = "pre-activation";
        };
      });
  };
}
