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
, buildGoCache
, ...
}:
let
  name = "services-go";
  src = util.devGoSrc;

  goCache = buildGoCache {
    inherit src;
    importPackagesFile = ../go-cache.imported-packages;
    vendorHash = null;
    vendorEnv = ../vendor;
  };

  bin = buildGoModule {
    inherit name src;
    vendorHash = null;
    env.CGO_ENABLED = 1;
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ goCache ];
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
    config.Env = [ "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt" ];
  };
in
binaryEnv // { inherit image bin; }
