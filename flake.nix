{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    # pinned because https://github.com/NixOS/nixpkgs/issues/332957 breaks things
    nixpkgs-pre-rust-180.url = "github:nixos/nixpkgs/c3392ad349a5227f4a3464dce87bcc5046692fce";

    utils.url = "github:numtide/flake-utils";
    filters.url = "github:numtide/nix-filter";

    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs.follows = "nixpkgs-master";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-master";
    };
    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    go-cache = {
      url = "github:numtide/build-go-cache";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, cottand, home-manager, utils, attic, filters, go-cache, ... }:
    let
      overrides = final: prev:
        let
          preRust180Pkgs = (import inputs.nixpkgs-pre-rust-180 { system = prev.system; config.allowUnfree = true; });
          goCachePkgs = go-cache.legacyPackages.${prev.system};
          selfPkgs = self.legacyPackages.${prev.system};
        in
        {
          inherit (goCachePkgs) buildGoCache get-external-imports;
          inherit (selfPkgs) scripts util;
          inherit (preRust180Pkgs) bws attic;
          #          vault-bin = (import inputs.nixpkgs-master { system = prev.system; config.allowUnfree = true; }).vault-bin;
        };
      overlays = [
        overrides
        attic.overlays.default
        filters.overlays.default
      ];
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
      colmena = (import ./hive.nix) (inputs // { inherit overlays; });
    }
  ;
}
