{
  meta = {
    nixpkgs = (import ./sources.nix).nixos-23-05-2;

    nodeNixpkgs = {
      #   elvis = (import (import ./sources.nix).nixos-22-11);
    };

    # can be used for distributed builds instead of buildOnTraget
    # machinesFile = ./machines/remote-builders;
  };

  defaults = { pkgs, lib, name, ... }: {
    imports = [
      ./machines/common_config.nix
      # make wireguard interface for mesh for all services
      # this will break if there is no corresponding config under secret/wg-mesh
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    nixpkgs.system = "x86_64-linux";
    networking.hostName = lib.mkDefault name;

    deployment.replaceUnknownProfiles = lib.mkDefault true;
    deployment.buildOnTarget = lib.mkDefault true;
    deployment.targetHost = lib.mkDefault "${name}.vpn.dcotta.eu";
  };

  cosmo = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.targetHost = "${name}.vps.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" ];
  };
  ari = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    networking.hostName = name;
    deployment.tags = [ "local" "nomad-server" ];
  };
  maco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.tags = [ "local" "nomad-server" ];
  };
  elvis = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.tags = [ "local" "nomad-client" ];
  };
  bianco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ./machines/laptop_config.nix
    ];
    deployment.tags = [ "madrid" "nomad-client" ];
  };
}
