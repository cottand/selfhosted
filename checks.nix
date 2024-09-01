/**
  All the attributes of this set should be derivations that always build successfully.
  These are used to validate that this repo and this flake
*/
{ self, system, stdenvNoCC, lib, ... }:
let
  inherit (lib.asserts) assertMsg;
  inherit (self.legacyPackages.${system}) services;
  noDerivationTest = { name, errorMsg, checkPhase ? "", assertThat ? true, }:
    stdenvNoCC.mkDerivation {
      inherit checkPhase name;
      dontBuild = true;
      doCheck = true;
      src = ./.;
      installPhase = ''
        mkdir "$out"
      '';
      _ASSERT = assertMsg assertThat errorMsg;
    };
  servicesBins = builtins.mapAttrs (_: svc: svc.bin) services;
in servicesBins
