{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "s-web-portfolio";

  src = util.cleanSourceForService name;

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/1810c8bcf8d4b06eff20d1637e413eef23d7098b").packages.${system}.static
    ];
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
in
binaryEnv // { inherit image bin; }
