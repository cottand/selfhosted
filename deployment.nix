let
  sources = import ./sources.nix;

  defaultArch = "x86_64-linux";
  defaultPkgs = sources.nixos-unstable;
  #  defaultPkgs = sources."nixos-20.11";

  lib = import (defaultPkgs + "/lib");

  machines = {
    #    "maco.vpn.dcotta.eu" = {
    #      system = "aarch64-linux"; darwin instead?
    #      packages = sources.nixos-unstable;
    #    };
    "ari.vpn.dcotta.eu" = {
      #    "192.168.50.79" = {
      name = "ari";
      #      system = "aarch64-linux";
      #      packages = sources.nixos-unstable;
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
        tags = [ system ];
      };
    };
in
{
  network = {
    inherit lib;
    description = "local";

    ordering = {
      tags = [ "ari" ];
    };
    evalConfig = machineName:
      (machines."${machineName}".packages or defaultPkgs) + "/nixos/lib/eval-config.nix";
  };
} // (lib.mapAttrs mkMachine machines)
