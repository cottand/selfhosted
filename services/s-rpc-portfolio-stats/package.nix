{ lib, util, buildGoModule, dockerTools, bash, buildEnv, system, protobuf, protoc-gen-go, ... }:
let
  name = "s-rpc-portfolio-stats";

  src = util.cleanSourceForService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [ ];
  };

  bin = buildGoModule {
    inherit name src;
    subPackages = [ name ];
    vendorHash = null;
    ldflags = [ "-X github.com/cottand/selfhosted/services/lib/bedrock.nixAssetsDir=${assetsEnv.outPath}" ];
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
