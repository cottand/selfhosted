{ buildGoModule, dockerTools, bash, buildEnv, ... }:
let
  name = "portfolioStats";
  bin = buildGoModule ({
    name = "portfolioStats";
    src = ../.;
    subPackages = [ "portfolioStats" ];
    vendorHash = null;
  });
  image = dockerTools.buildImage {
    inherit name;
    tag = "latest";
    copyToRoot = buildEnv {
      inherit name;
      paths = [ bash bin ];
      pathsToLink = [ "/bin" ];
    };
    config.Cmd = [ "/bin/${name}" ];
  };
in
bin // { image = image; }
