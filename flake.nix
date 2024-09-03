{
  inputs = {
    # pinned because https://github.com/NixOS/nixpkgs/issues/332957 breaks bws
    nixpkgs.url = "github:nixos/nixpkgs/c3392ad349a5227f4a3464dce87bcc5046692fce";
    nixpkgs-master.url = "github:nixos/nixpkgs";

    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs-unstable.follows = "nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
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

    utils.url = "github:numtide/flake-utils";
    filters.url = "github:numtide/nix-filter";
  };

  outputs = inputs@{ self, nixpkgs, cottand, home-manager, utils, nixpkgs-master, attic, filters, ... }:
    let
      newVault = final: prev: {
        vault-bin = (import nixpkgs-master { system = prev.system; config.allowUnfree = true; }).vault-bin;
      };
      withScripts = final: prev: {
        scripts = self.legacyPackages.${prev.system}.scripts;
        util = self.legacyPackages.${prev.system}.util;
      };
      overlays = [
        (import ./overlay.nix)
        withScripts
        newVault
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
