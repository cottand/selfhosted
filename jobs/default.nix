{ config, ... }:
let
  lib = (import ./lib) { };
in
{
  imports = [
    ./modules
    ./whoami.nix
    ./filestash.nix
  ];
}

