{ buildGoModule
, dockerTools
, bash
, buildEnv
, system
, util
, curlMinimal
, pkg-config
, nixVersions
, cacert
, ...
}:
let
  name = "services-go";
  src = util.devGoSrc;

  bin = buildGoModule {
    inherit name src;
    vendorHash = null;
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ nixVersions.nix_2_23 ];
    CGO_ENABLED = 1;
    subPackages = [ "services" ];
    postInstall = ''
      mv $out/bin/services $out/bin/${name}
    '';
  };

  binaryEnv = buildEnv {
    inherit name;
    paths = [ (bin.overrideAttrs { doCheck = false; }) bash curlMinimal ];
  };
  image = dockerTools.buildImage {
    inherit name;
    copyToRoot = binaryEnv;
    config.Cmd = [ "/bin/${name}" ];
    config.Env = [
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
in
binaryEnv // { inherit image bin; }
