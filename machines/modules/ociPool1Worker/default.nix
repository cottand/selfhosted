{ name, pkgs, lib, config, ... }:
with lib;
let
  cfg = config.nodeType.ociPool1Worker;
in
{
  options.nodeType.ociPool1Worker = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    imports = [ ./hardware-configuration.nix ];

    system.stateVersion = "23.11";
  };
}

