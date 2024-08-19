{ lib, util, buildGoModule, dockerTools, bash, buildEnv, system, protobuf, protoc-gen-go, ... }:
let
  name = "s-portfolio-stats";

  src = util.cleanSourceForService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [ ];
  };

  bin = buildGoModule {
    inherit name src;
    subPackages = [ name ];
    vendorHash = null;
    GOFLAGS = [ "-tags=in_nix" ];
    preBuild = ''
      sed -i 's|_TO_REPLACE_BY_NIX__ASSETS_ENV|${assetsEnv.outPath}|g' lib/bedrock/in_nix.go
    '';
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ bin assetsEnv bash ];
  };

  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = binaryEnv;
    config.Cmd = [ "/bin/${name}" ];
  };
  protos = util.protosFor name;
in
binaryEnv // { inherit image bin protos; }
