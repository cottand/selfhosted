{ lib
, nix-filter
, runCommand
, protobuf
, protoc-gen-go
, ...
}:
let
  inherit (lib) sources;
in
rec {
  cleanNixFiles = src: nix-filter {
    root = src;
    exclude = [ (nix-filter.matchExt "nix") ];
  };

  servicesSrc = cleanNixFiles (sources.cleanSource ./services);

  cleanSourceForService = name: nix-filter {
    root = servicesSrc;
    include = [ "lib" "vendor" "go.mod" "go.sum" name ];
  };

  /**
    Produces protos for serviceName as files under $out
  */
  protosFor = serviceName:
    let
      svc = "${cleanSourceForService serviceName}/${serviceName}";
      protoPath = "${svc}/def.proto";
    in
    runCommand "protos-for-${serviceName}"
      {
        nativeBuildInputs = [ protobuf protoc-gen-go ];
      }
      ''
        mkdir $out
        ${if (builtins.pathExists protoPath) then "protoc -I=${svc} --go_out=$out --go_opt=paths=source_relative def.proto" else ""}
      '';
}
