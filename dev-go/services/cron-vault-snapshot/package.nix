{ buildGoModule, dockerTools, bash, buildEnv, util, ... }:
let
  name = builtins.baseNameOf ./.;

  src = util.cleanSourceForGoService name;

  bin = buildGoModule {
    inherit name src;
    subPackages = [ "services/${name}" ];
    vendorHash = null;
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ bin ];
  };
  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = binaryEnv;
    config.Cmd = [ "/bin/${name}" ];
  };
in
binaryEnv // { inherit image bin; }
