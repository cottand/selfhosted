{ buildGoModule, dockerTools, bash, buildEnv, writeShellScriptBin, ... }:
let
  name = "portfolioStats";
  bin = buildGoModule ({
    inherit name;
    src = ../.;
    subPackages = [ name ];
    vendorHash = null;
  });
  start = writeShellScriptBin "start" "${bin}/bin/${name}";
  image = dockerTools.buildImage {
    name = "service";
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
