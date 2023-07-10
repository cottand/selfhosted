let
  sources = import ./sources.nix;

  defaultArch = "x86_64-linux"; # alternative: "aarch64-linux";
  defaultPkgs = sources.nixos-22-11;

  lib = import (defaultPkgs + "/lib");

  machines = {
    "ari.vpn.dcotta.eu" = {
      #  "192.168.50.79" = {
      name = "ari";
      packages = sources.nixos-23-05-cottand-6;
    };
    "elvis.vpn.dcotta.eu" = {
    # "192.168.50.184" = {
      name = "elvis";
      packages = sources.nixos-23-05-cottand-6;
    };
    "maco.vpn.dcotta.eu" = {
      name = "maco";
      packages = sources.nixos-23-05-cottand-6;
    };
    "cosmo.vps.dcotta.eu" = {
      name = "cosmo";
      packages = sources.nixos-23-05-cottand-6;
    };
  };

  mkMachine = hostName: { name, system ? defaultArch, packages ? defaultPkgs }:
    let
      pkgs = import packages {
        inherit system;
      };
    in
    { config, ... }: {
      imports = [
        (./${name} + "/definition.nix")
        ./common_config.nix
      ];
      nixpkgs.pkgs = pkgs;
      nixpkgs.crossSystem.config = "x86_64-unknown-linux-gnu";
      nixpkgs.localSystem.system = system;
      deployment = {
        substituteOnDestination = true;
        tags = [ name system ];
      };
    };
in
{
  network = {
    inherit lib;
    description = "local";

    ordering = {
      tags = [ "elvis" ];
    };
    evalConfig = machineName:
      (machines."${machineName}".packages or defaultPkgs) + "/nixos/lib/eval-config.nix";
  };
} // (lib.mapAttrs mkMachine machines)
