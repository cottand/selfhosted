{ lib
, nomad_1_9
, util
, buildGoModule
, pkg-config
, nixVersions
, makeWrapper
, installShellFiles
, ...
}:
let
  name = "shipper";
in
buildGoModule {
  inherit name;
  src = util.devGoSrc;
  vendorHash = null;
  nativeBuildInputs = [ pkg-config makeWrapper installShellFiles ];
  buildInputs = [ nixVersions.nix_2_23 ];
  subPackages = [ "cmd/${name}" ];
  env.CGO_ENABLED = 1;
  postInstall = ''
    wrapProgram $out/bin/shipper --prefix PATH : ${lib.makeBinPath [ nomad_1_9 ]}

    mkdir -p share/completions
    $out/bin/${name} completion bash > share/completions/${name}.bash
    $out/bin/${name} completion fish > share/completions/${name}.fish
    $out/bin/${name} completion zsh > share/completions/${name}.zsh

    # implicit behavior
    installShellCompletion share/completions/${name}.{bash,fish,zsh}
  '';
}
