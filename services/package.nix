{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "services-go";
  src = util.servicesSrc;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/b3a332df247ba997cd7da4aa0ed05e0ef98ec30c").packages.${system}.static
    ];
  };

  bin = buildGoModule {
    inherit name src;
    vendorHash = null;
    ldflags = [ "-X github.com/cottand/selfhosted/services/lib/bedrock.nixAssetsDir=${assetsEnv.outPath}" ];
    postInstall = ''
      mv $out/bin/services $out/bin/${name}
    '';
  };
  binaryEnv = buildEnv {
    inherit name;
    paths = [ (bin.overrideAttrs { doCheck = false; }) assetsEnv bash ];
  };
  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = binaryEnv;
    config.Cmd = [ "/bin/${name}" ];
  };
in
binaryEnv // { inherit image bin; }
