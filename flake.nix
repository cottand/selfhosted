{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    # pinned because https://github.com/NixOS/nixpkgs/issues/332957 breaks things
    nixpkgs-pre-rust-180.url = "github:nixos/nixpkgs/c3392ad349a5227f4a3464dce87bcc5046692fce";
    nixpkgs-24-05.url = "github:nixos/nixpkgs/24.05";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

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
          preRust180Pkgs = (import inputs.nixpkgs-pre-rust-180 { system = prev.system; config.allowUnfree = true; });
          goCachePkgs = go-cache.legacyPackages.${prev.system};
          selfPkgs = self.legacyPackages.${prev.system};
          pkgs2405 = (import inputs.nixpkgs-24-05 { system = prev.system; config.allowUnfree = true; });
        in
        {
          inherit (goCachePkgs) buildGoCache get-external-imports;
          inherit (selfPkgs) scripts util;
          inherit (preRust180Pkgs) bws attic;
          # unstable did not support darwin as of 11/10/24
          inherit (pkgs2405) wrangler;
          #          vault-bin = (import inputs.nixpkgs-master { system = prev.system; config.allowUnfree = true; }).vault-bin;
          nomad_1_9 = prev.nomad_1_9.overrideAttrs
            (oldAttrs: rec {
              version = "1.9.3";
              vendorHash = "sha256-paUI5mYa9AvMsI0f/VeVdnZzwKS9gsBIb6T4KmugPKQ=";
              src = prev.fetchFromGitHub {
                owner = "hashicorp";
                repo = "nomad";
                rev = "v${version}";
                hash = "sha256-KjVr9NIL9Qw10EoP/C+2rjtqU2qBSF6SKpIvQWQJWuo=";
              };
            });
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
      }
    )) // {
      colmenaHive = colmenaHive // {
        findByTag = with builtins; tag:
          filter (name: elem tag colmenaHive.nodes.${name}.config.deployment.tags) (attrNames colmenaHive.nodes);
      };
      colmena = (import ./hive.nix) (inputs // { inherit overlays; });
    }
  ;
}
