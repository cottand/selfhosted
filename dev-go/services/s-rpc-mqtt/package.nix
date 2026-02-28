{ lib
, util
, buildGoModule
, dockerTools
, bash
, buildEnv
, system
, protobuf
, protoc-gen-go
, nixVersions
, pkg-config
, ...
}:
let
  name = builtins.baseNameOf ./.;

  src = util.cleanSourceForGoService name;

  bin = buildGoModule {
    inherit name src;
    subPackages = [ "services/${name}" ];
    vendorHash = null;
  };

  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = imageEnv;
    config.Cmd = [ "/bin/${name}" ];
  };

  imageEnv = buildEnv {
    inherit name;
    paths = [ (bin.overrideAttrs { doCheck = false; }) bash ];
  };
  protos = util.protosFor name;
in
imageEnv // { inherit image bin protos; }
