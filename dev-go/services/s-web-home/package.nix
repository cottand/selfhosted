{ buildGoModule, bash, buildEnv, util, gsx, ... }:
let
  name = "s-web-home";

  src = util.cleanSourceForGoService name;

  bin = buildGoModule {
    inherit name src;
    subPackages = [ "services/${name}" ];
    vendorHash = null;
    nativeBuildInputs = [ gsx ];
    env.GSXCACHE = "off";
    preBuild = ''
      go generate ./services/${name}/...
    '';
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ bin bash ];
  };
in
binaryEnv // { inherit bin; }
