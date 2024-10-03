{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "s-web-portfolio";

  src = util.cleanSourceForGoService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/c5cb2fa3866f67238e51c1c2896c63c3fac56c76").packages.${system}.static
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
