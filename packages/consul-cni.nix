{ buildGoApplication
, fetchFromGitHub
, runCommand
, govendor
, go
, ...
}:
let
  version = "2.0.3";
  consul-k8s = fetchFromGitHub {
    owner = "hashicorp";
    repo = "consul-k8s";
    tag = "v${version}";
    hash = "sha256-pfwF1ffFZ28aLk5E62VbrGlSAGoGk1i3DWnUd8NUWpA=";
  };
in
buildGoApplication rec {
  inherit version go;
  pname = "consul-cni";

  src = "${consul-k8s}/control-plane/cni";
  # you'll need to update govendor if you update the version
  # I did it by cloning the repo at the right tag and running `govendor` :c
  modules = ./govendor.toml;

  vendorHash = "sha256-tFa8UKeaAQR4q+WpRl/u5P+TpjdBh9Gf6bVQcwzP5BB=";

  localReplaces = {
    "github.com/hashicorp/consul-k8s/version" = "${consul-k8s}/version";
  };

  doCheck = false;

  postInstall = ''
    mv $out/bin/cni $out/bin/consul-cni
  '';

  ldflags = [
    "-X github.com/hashicorp/consul/version.GitDescribe=v${version}"
    "-X github.com/hashicorp/consul/version.Version=${version}"
    "-X github.com/hashicorp/consul/version.VersionPrerelease="
  ];
}
