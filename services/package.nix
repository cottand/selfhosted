{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "services-go";
  src = ./.;

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
    GOFLAGS = [ "-tags=in_nix" ];
    postPatch = ''
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
