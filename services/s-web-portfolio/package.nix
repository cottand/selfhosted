{ buildGoModule, dockerTools, bash, buildEnv, system, ... }:
let
  name = "s-web-portfolio";

  assetsEnv = buildEnv {
    name = "${name}-assets";
    paths = [
      # has files under /srv
      (builtins.getFlake "github:cottand/web-portfolio/9a3ef3ce42be7b20de6d312f1264d4a2d75b99ec").packages.${system}.static
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
