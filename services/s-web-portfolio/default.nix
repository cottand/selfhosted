{ buildGoModule, dockerTools, bash, busybox, buildEnv, writeShellScriptBin, system, ... }:
let
  name = "s-web-portfolio";
  bin = buildGoModule ({
    inherit name;
    src = ../.;
    subPackages = [ name ];
    vendorHash = null;
  });
  binWithWeb = buildEnv {
    inherit name;
    paths = [ bin web bash busybox ];
  };
  # has files under /srv
  web = (builtins.getFlake "github:cottand/web-portfolio/148bf78b0fa4b87c73079274c629f1e02564867d").packages.${system}.static;
  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = binWithWeb;
    config.Cmd = [ "/bin/${name}" ];
  };
in
binWithWeb // { image = image; }
