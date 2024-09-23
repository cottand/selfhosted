{
  inputs = {
    # pinned because https://github.com/NixOS/nixpkgs/issues/332957 breaks bws
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";
    nixpkgs-pre-rust-180.url = "github:nixos/nixpkgs/c3392ad349a5227f4a3464dce87bcc5046692fce";

    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs-unstable.follows = "nixpkgs-master";
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

    utils.url = "github:numtide/flake-utils";
    filters.url = "github:numtide/nix-filter";
  };

  outputs = inputs@{ self, nixpkgs, cottand, home-manager, utils, attic, filters, go-cache, ... }:
    let
      pinnedAt = final: prev:
        let
          preRust180 = (import inputs.nixpkgs-pre-rust-180 { system = prev.system; config.allowUnfree = true; });
        in
        {
          vault-bin = (import inputs.nixpkgs-master { system = prev.system; config.allowUnfree = true; }).vault-bin;
          bws = preRust180.bws;
          attic = preRust180.attic;
        };
      withScripts = final: prev: {
        scripts = self.legacyPackages.${prev.system}.scripts;
        util = self.legacyPackages.${prev.system}.util;
      };
      overlays = [
        (import ./overlay.nix)
        withScripts
        pinnedAt
        attic.overlays.default
        filters.overlays.default
        (_: prev: {
          inherit (go-cache.legacyPackages.${prev.system}) buildGoCache get-external-imports;
        })
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
