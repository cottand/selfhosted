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
      paths = with pkgs; [ bash cacert github-runner scripts.start-gh-runner ];
    };
    config.Cmd = [ "/bin/start-gh-runner" ];
    config.Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
