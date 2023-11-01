{
  meta = {
    nixpkgs = (import ./sources.nix).nixos-23-05-3;

    nodeNixpkgs = {
      #   elvis = (import (import ./sources.nix).nixos-22-11);
      # miki = (import ./sources.nix).nixos-local-dev;
      nico-xps = (import ./sources.nix).nixos-23-05-5;
    };
  };

  defaults = { pkgs, lib, name, nodes, ... }: {
    imports = [
      ./machines/common_config.nix
      ./modules
    ];
    nixpkgs.system = "x86_64-linux";
    networking.hostName = lib.mkDefault name;

    deployment.replaceUnknownProfiles = lib.mkDefault true;
    deployment.buildOnTarget = lib.mkDefault true;
    deployment.targetHost = lib.mkDefault "${name}.mesh.dcotta.eu";

    # custom.wireguard = lib.mkIf (!nodes."${name}".config.deployment.allowLocalDeployment) {
      
    # };
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
    ];
    deployment.targetHost = "${name}.vps.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" ];
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };


  miki = { name, nodes, lib, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.targetHost = "${name}.vps.dcotta.eu";
    nixpkgs.system = lib.mkForce "aarch64-linux";
    deployment.tags = [ "hetzner" "nomad-client" ];
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };

  # ari = { name, nodes, ... }: {
  #   imports = [
  #     ./machines/${name}/definition.nix
  #   ];
  #   networking.hostName = name;
  #   deployment.tags = [ "local" "nomad-server" ];
  #   custom.wireguard."wg-mesh" = {
  #     enable = true;
  #     confPath = secret/wg-mesh/${name}.conf;
  #     port = 55820;
  #   };
  # };

  maco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.tags = [ "contabo" "nomad-server" ];
    # TODO CHANGE
    deployment.targetHost = "maco.vps6.dcotta.eu";
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };

  elvis = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.targetHost = "elvis.vps6.dcotta.eu";
    deployment.tags = [ "local" "nomad-client" ];
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };

  ziggy = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
    ];
    deployment.tags = [ "local" "nomad-client" ];
    deployment.targetHost = "ziggy.vps6.dcotta.eu"; # TODO CHANGE
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };

  bianco = { name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ./machines/laptop_config.nix
    ];
    deployment.tags = [ "madrid" "nomad-client" ];
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };
}
