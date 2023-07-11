{
  meta = {
    nixpkgs = (import ./sources.nix).nixos-23-05-cottand-6;

    nodeNixpkgs = {
    #   elvis = (import (import ./sources.nix).nixos-22-11);
    };

    # can be used for distributed builds instead of buildOnTraget
    # machinesFile = ./machines.client-a;
  };

  defaults = { pkgs, ... }: {
    imports = [ ./machines/common_config.nix ];
    nixpkgs.system = "x86_64-linux";
    deployment.replaceUnknownProfiles = false;
    deployment.buildOnTarget = true;
  };

  cosmo = { name, nodes, ... }: {
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "contabo" "nomad-server" ];
  };
  ari = { name, nodes, ... }: {
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "nomad-server" ];
  };
  maco = { name, nodes, ... }: {
    networking.hostName = name;
    deployment.targetHost = "${name}.vpn.dcotta.eu";
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "nomad-server" ];
  };
  elvis = { name, nodes, ... }: {
    networking.hostName = name;
    deployment.targetHost = "elvis.vpn.dcotta.eu";
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "nomad-client" ];
    nixpkgs.system = "x86_64-linux";
  };
}
