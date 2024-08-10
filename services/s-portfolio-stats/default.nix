{ buildGoModule, dockerTools, bash, buildEnv, writeShellScriptBin, ... }:
let
  name = "s-portfolio-stats";
  bin = buildGoModule ({
    inherit name;
    src = ../.;
    subPackages = [ name ];
    vendorHash = null;
  });
  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = buildEnv {
      inherit name;
      paths = [ bash bin ];
      pathsToLink = [ "/bin" ];
    };
    config.Cmd = [ "/bin/${name}" ];
  };
in
bin // { image = image; }
