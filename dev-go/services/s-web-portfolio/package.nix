{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "s-web-portfolio";

  src = util.cleanSourceForGoService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/c598fd71d82a5accda0d5bfcae5079ded9d6efe4").packages.${system}.static
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
