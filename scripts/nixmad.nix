{ lib
, nomad_1_8
, util
, buildGoModule
, pkg-config
, nixVersions
, makeWrapper
, ...
}:
let
  name = "nixmad";
in
buildGoModule {
  inherit name;
  src = util.devGoSrc;
  vendorHash = null;
  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ nixVersions.nix_2_23 ];
  subPackages = [ "cmd/${name}" ];
  CGO_ENABLED = 1;
  postInstall = ''
    wrapProgram $out/bin/nixmad --prefix PATH : ${lib.makeBinPath [ nomad_1_8 ]}
  '';
}
