{ buildGoModule, dockerTools, bash, buildEnv, system, ... }:
let
  name = "s-web-portfolio";

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/148bf78b0fa4b87c73079274c629f1e02564867d").packages.${system}.static
    ];
  };

  bin = buildGoModule {
    inherit name;
    src = ./..;
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
