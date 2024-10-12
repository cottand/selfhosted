{ buildGoModule, dockerTools, bash, buildEnv, system, util, ... }:
let
  name = "s-web-portfolio";

  src = util.cleanSourceForGoService name;

  bin = buildGoModule {
    inherit name src;
    subPackages = [ "services/${name}" ];
    vendorHash = null;
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ bin bash ];
  };
in
binaryEnv // { inherit bin; }
