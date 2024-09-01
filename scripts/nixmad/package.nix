{ lib
, nix
, nomad
, util
, runCommand
, substituteAll
, makeWrapper
, ...
}:
let
  nixmadYaegi = util.buildYaegiScript "nixmad" (substituteAll {
    src = ./nixmad.go;
    applyOnJobNixPath = ./applyOnJob.nix;
  });
in
# absolute hack to be able to pass arguments to loose job.nix files
runCommand "nixmad" { nativeBuildInputs = [ makeWrapper ]; } ''
  mkdir -p $out/bin
  cp ${nixmadYaegi}/bin/nixmad $out/bin/nixmad

  wrapProgram $out/bin/nixmad \
          --prefix PATH : ${lib.makeBinPath [ nix nomad ]} \
          --set YAEGI_SYSCALL 1 \
          --set YAEGI_UNRESTRICTED 1 \
          --set YAEGI_UNSAFE 1
''
