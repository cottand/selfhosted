{ self
, callPackage
, dockerTools
, pkgs
, scripts
, ...
}: {

  gh-runner = dockerTools.buildImage rec {
    name = "i-gh-runner";
    copyToRoot = pkgs.buildEnv {
      inherit name;
      paths = with pkgs; [
        bash
        cacert
        github-runner
        busybox
        skopeo
        scripts.start-gh-runner
      ];
    };
    config.Cmd = [ "/bin/start-gh-runner" ];
  };

  attic = self.inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.attic-server-image;
}
