{ lib
, self
, system
, nix-filter
, runCommand
, runCommandLocal
, protobuf
, protoc-gen-go
, protoc-gen-go-grpc
, buildEnv
, symlinkJoin
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
        nativeBuildInputs = [ protobuf protoc-gen-go protoc-gen-go-grpc ];
      }
      ''
        mkdir $out
        ${if (builtins.pathExists protoPath)
        then
         "protoc -I=${svc} --go_out=$out --go_opt=paths=source_relative --go-grpc_out=$out --go-grpc_opt=paths=source_relative def.proto"
          else
           ""}
      '';

  protosForAllServices =
    let
      services = builtins.attrNames self.legacyPackages.${system}.services;
      perServiceCommand = map
        (name: (if (self.legacyPackages.${system}.services.${name} ? "protos") then
          ''
            generated=${protosFor name}
            dest="$out/${name}"
            mkdir -p $dest
            cp -r $generated/*.pb.go $dest
          '' else ""
        ))
        services;
      concatted = builtins.concatStringsSep "\n" perServiceCommand;
    in
    runCommandLocal "protos-all-services" { } concatted;
}
