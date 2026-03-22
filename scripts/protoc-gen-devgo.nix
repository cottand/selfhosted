{ lib
, util
, buildGoModule
, pkg-config
, nixVersions
, makeWrapper
, installShellFiles
, ...
}:
let
  name = "protoc-gen-devgo";
in
buildGoModule {
  inherit name;
  src = util.devGoSrc;
  vendorHash = null;
  subPackages = [ "cmd/${name}" ];
  env.CGO_ENABLED = 0;
}
