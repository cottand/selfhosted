{
  meta = {
    nixpkgs = (import ./sources.nix).nixos-23-05-cottand-7;

    nodeNixpkgs = {
      #   elvis = (import (import ./sources.nix).nixos-22-11);
    };

    # can be used for distributed builds instead of buildOnTraget
    # machinesFile = ./machines/remote-builders;
  };

  defaults = { pkgs, lib, ... }: {
    imports = [ ./machines/common_config.nix ];
    nixpkgs.system = "x86_64-linux";
    deployment.replaceUnknownProfiles = lib.mkDefault true;
    deployment.buildOnTarget = true;
  };

  cosmo = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" ];
  };
  ari = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    deployment.tags = [ "local" "nomad-server" ];
  };
  maco = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    deployment.tags = [ "local" "nomad-server" ];
  };
  elvis = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    deployment.tags = [ "local" "nomad-client" ];
  };
  bianco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ./machines/laptop_config.nix
    ];
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    deployment.tags = [ "madrid" "nomad-client" ];
  };
}
