{ lib, util, buildGoModule, dockerTools, bash, buildEnv, system, protobuf, protoc-gen-go, ... }:
let
  name = "s-rpc-nomad-api";

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
  protos = util.protosFor name;
in
binaryEnv // { inherit bin protos; }
