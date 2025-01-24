{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    nixpkgs-24-11.url = "github:nixos/nixpkgs/nixos-24.11";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    nix.url = "github:nixos/nix/2.23.4";

    utils.url = "github:numtide/flake-utils";
    filters.url = "github:numtide/nix-filter";

    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs.follows = "nixpkgs-master";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    go-cache = {
      url = "github:numtide/build-go-cache";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixnomad = {
      url = "github:cottand/nix-nomad";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };
  };

  outputs = inputs@{ self, nixpkgs, cottand, home-manager, utils, attic, filters, go-cache, colmena, ... }:
    let
      colmenaHive = colmena.lib.makeHive self.outputs.colmena;
      overlays = [
        overrides
        attic.overlays.default
        filters.overlays.default
        colmena.overlays.default
      ];
      overrides = final: prev:
        let
          goCachePkgs = go-cache.legacyPackages.${prev.system};
          selfPkgs = self.legacyPackages.${prev.system};
        in
        {
          inherit (goCachePkgs) buildGoCache get-external-imports;
          inherit (selfPkgs) scripts util;

          nixVersions = prev.nixVersions // {
            # .. which was removed in unstable, but compiles with gonix
            nix_2_23 = inputs.nix.packages.${prev.system}.nix;
          };

          vault-bin = (import inputs.nixpkgs-master { system = prev.system; config.allowUnfree = true; }).vault-bin;
        };
    in
    (utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        pkgsWithSelf = pkgs // { inherit self; };
      in
      rec {

        legacyPackages.services = (import ./dev-go/services) pkgs;
        legacyPackages.scripts = (import ./scripts) pkgsWithSelf;
        legacyPackages.util = (import ./util.nix) pkgsWithSelf;
        legacyPackages.images = (import ./images.nix) pkgsWithSelf;

        packages = legacyPackages.scripts;

        devShells.default = (import ./shell.nix) pkgsWithSelf;

        checks = (import ./checks.nix) pkgsWithSelf;

        formatter = pkgs.writeShellScriptBin "fmt" ''
          ${pkgs.nomad}/bin/nomad fmt
          ${pkgs.terraform}/bin/terraform fmt
        '';

        nomadJobs = inputs.nixnomad.lib.evalNomadJobs {
          inherit system pkgs;

          extraArgs.self = self;
          extraArgs.util = import ./jobs/jobsUtil.nix {};

          config = {
            imports = [ ./jobs ];
          };
        };

      }
    )) // {
      colmenaHive = colmenaHive // {
        findByTag = with builtins; tag:
          filter (name: elem tag colmenaHive.nodes.${name}.config.deployment.tags) (attrNames colmenaHive.nodes);
      };
      colmena = (import ./hive.nix) (inputs // { inherit overlays; });

      rootCa = ./certs/root_2024_ca.crt;
    }
  ;
}
