/**
  All the attributes of this set should be derivations that always build successfully.
  These are used to validate that this repo and this flake
*/
{ self, system, stdenvNoCC, lib, ... }:
let
  inherit (lib.asserts) assertMsg;
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
in
{
  servicesHaveImageAttribute = noDerivationTest {
    name = "services-have-image-attribute";
    assertThat = with builtins;
      let
        services = self.legacyPackages.${system}.services;
        hasImageAttr = name: svc: assertMsg (svc ? "image") "expected to find .image attribute in ${svc}";
      in
      all (x: x) (attrValues (mapAttrs hasImageAttr services));
    errorMsg = "expected all services to have a .image attribute";
  };

}
