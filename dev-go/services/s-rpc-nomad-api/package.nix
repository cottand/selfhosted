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
  name = "s-rpc-nomad-api";

  src = util.cleanSourceForGoService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [ ];
  };

  bin = buildGoModule {
    inherit name src;
    subPackages = [ "services/${name}" ];
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ nixVersions.nix_2_22 ];
    env.CGO_ENABLED = 1;
    vendorHash = null;
    ldflags = [ "-X github.com/cottand/selfhosted/dev-go/lib/bedrock.nixAssetsDir=${assetsEnv.outPath}" ];
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ bin assetsEnv bash ];
  };
  protos = util.protosFor name;
in
binaryEnv // { inherit bin protos; }
