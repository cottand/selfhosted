{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "s-web-portfolio";

  src = util.cleanSourceForGoService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/b3a332df247ba997cd7da4aa0ed05e0ef98ec30c").packages.${system}.static
    ];
  };

  bin = buildGoModule {
    inherit name src;
    subPackages = [ "services/${name}" ];
    vendorHash = null;
    ldflags = [ "-X github.com/cottand/selfhosted/dev-go/lib/bedrock.nixAssetsDir=${assetsEnv.outPath}" ];
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ bin assetsEnv bash ];
  };
in
binaryEnv // { inherit bin; }
