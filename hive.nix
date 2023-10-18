{
  meta = {
    nixpkgs = (import ./sources.nix).nixos-23-05-3;

    nodeNixpkgs = {
      #   elvis = (import (import ./sources.nix).nixos-22-11);
      # miki = (import ./sources.nix).nixos-local-dev;
      nico-xps = (import ./sources.nix).nixos-23-05-5;
    };

    # can be used for distributed builds instead of buildOnTraget
    # machinesFile = ./machines/remote-builders;
  };

  defaults = { pkgs, lib, name, ... }: {
    imports = [
      ./machines/common_config.nix
      # make wireguard interface for mesh for all services
      # this will break if there is no corresponding config under secret/wg-mesh
    ];
    nixpkgs.system = "x86_64-linux";
    networking.hostName = lib.mkDefault name;

    deployment.replaceUnknownProfiles = lib.mkDefault true;
    deployment.buildOnTarget = lib.mkDefault true;
    deployment.targetHost = lib.mkDefault "${name}.mesh.dcotta.eu";
  };

  nico-xps = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];

    deployment = {
      # Allow local deployment with `colmena apply-local`
      allowLocalDeployment = true;

      # Disable SSH deployment. This node will be skipped in a
      # normal`colmena apply`.
      targetHost = null;
    };
  };


  cosmo = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    deployment.targetHost = "${name}.vps.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" ];
  };


  miki = { name, nodes, lib, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    deployment.targetHost = "${name}.vps.dcotta.eu";
    nixpkgs.system = lib.mkForce "aarch64-linux";
    deployment.tags = [ "hetzner" "nomad-client" ];
  };

  ari = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    networking.hostName = name;
    deployment.tags = [ "local" "nomad-server" ];
  };

  maco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    deployment.tags = [ "contabo" "nomad-server" ];
    # TODO CHANGE
    deployment.targetHost = "maco.vps6.dcotta.eu";
  };

  elvis = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    deployment.targetHost = "elvis.vps6.dcotta.eu";
    deployment.tags = [ "local" "nomad-client" ];
  };

  ziggy = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    deployment.tags = [ "local" "nomad-client" ];
    deployment.targetHost = "ziggy.vps6.dcotta.eu"; # TODO CHANGE
  };

  bianco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ./machines/laptop_config.nix
      ((import lib/make-wireguard.nix) { interface = "wg-mesh"; confPath = secret/wg-mesh/${name}.conf; port = 55820; })
    ];
    deployment.tags = [ "madrid" "nomad-client" ];
  };
}
