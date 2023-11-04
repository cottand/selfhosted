let
  nixos-23-05-channel = import (builtins.fetchTarball "https://api.github.com/repos/nixos/nixpkgs/tarball/nixos-23.05");
  nixos-23-05-pinned = import (builtins.fetchTarball"https://api.github.com/repos/nixos/nixpkgs/tarball/4d4a531350f3d41fc9065a14ff5bf3a1c41d1a83");
in
{
  meta = {
    nixpkgs = nixos-23-05-pinned;

    nodeNixpkgs = {
      nico-xps = nixos-23-05-channel;
    };
  };

  defaults = { pkgs, lib, name, nodes, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ./machines/common_config.nix
      ./modules
    ];
    nixpkgs.overlays = [ (import ./overlays.nix) ];
    nixpkgs.system = "x86_64-linux";
    networking.hostName = lib.mkDefault name;

    deployment.replaceUnknownProfiles = lib.mkDefault true;
    deployment.buildOnTarget = lib.mkDefault true;
    deployment.targetHost = lib.mkDefault "${name}.mesh.dcotta.eu";
  };

  nico-xps = { name, nodes, ... }: {
    deployment = {
      # Allow local deployment with `colmena apply-local`
      allowLocalDeployment = true;

      # Disable SSH deployment. This node will be skipped in a
      # normal`colmena apply`.
      targetHost = null;
    };
  };

  cosmo = { name, nodes, ... }: {
    deployment.targetHost = "${name}.vps.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" ];
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };


  miki = { name, nodes, lib, ... }: {
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
    deployment.tags = [ "contabo" "nomad-server" ];
    deployment.targetHost = "maco.mesh.dcotta.eu";
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };

  elvis = { name, nodes, ... }: {
    deployment.targetHost = "elvis.vps6.dcotta.eu";
    deployment.tags = [ "local" "nomad-client" ];
    custom.wireguard."wg-mesh" = {
      enable = true;
      confPath = secret/wg-mesh/${name}.conf;
      port = 55820;
    };
  };

  ziggy = { name, nodes, ... }: {
    imports = [ ];
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
