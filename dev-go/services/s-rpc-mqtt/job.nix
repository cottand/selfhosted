{ version
, ...
}:
let
  lib = (import ../../../jobs/lib) { };
in
lib.mkServiceGoGrpc rec {
  inherit version;
  name = builtins.baseNameOf ./.;
  resources = {
    cpu = 100;
    memoryMB = 150;
    memoryMaxMB = 400;
  };
  sidecarResources = lib.mkSidecarResourcesWithFactor 0.20 resources;
}
