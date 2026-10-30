{ buildGoModule
, fetchFromGitHub
, ...
}:
buildGoModule rec {
  pname = "gsx";
  # keep in sync with github.com/gsxhq/gsx in dev-go/go.mod
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "gsxhq";
    repo = "gsx";
    tag = "v${version}";
    hash = "sha256-6YV3uViBGanUmJkKVmxlnQIGbb3jeVoNzfhiUZD0//U=";
  };

  vendorHash = "sha256-EN5VAM35pW1NGNShlNr8+m7Ymn+uFAMxod1KQXUoeGc=";

  subPackages = [ "cmd/gsx" ];

  doCheck = false;
}
