{ lib
, self
, system
, nix-filter
, runCommand
, runCommandLocal
, protobuf
, protoc-gen-go
, protoc-gen-go-grpc
, writeScriptBin
, yaegi
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

  devGoSrc = cleanNixFiles (sources.cleanSource ./dev-go);

  cleanSourceForGoService = name: nix-filter {
    root = devGoSrc;
    include = [ "lib" "vendor" "go.mod" "go.sum" "services/${name}" ];
  };

  /**
    Produces protos for serviceName as files under $out
  */
  protosFor = serviceName:
    let
      svc = "${cleanSourceForGoService serviceName}/services";
      protoPath = "${svc}/${serviceName}/def.proto";
#      go_opt = "module=github.com/Cottand/selfosted/dev-go/lib/proto";
            go_opt="paths=source_relative";
    in
    runCommand "protos-for-${serviceName}"
      {
        nativeBuildInputs = [ protobuf protoc-gen-go protoc-gen-go-grpc ];
      }
      ''
        mkdir $out
        ${if (builtins.pathExists protoPath)
        then
         ''
           pushd ${svc}
           protoc -I=./ --go_out=$out --go_opt=${go_opt} --go-grpc_out=$out --go-grpc_opt=${go_opt} ${serviceName}/*.proto
           popd
           mv $out/${serviceName}/* $out
           rm -rf $out/${serviceName}
           ''
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

  buildYaegiScript = name: filePath: writeScriptBin name ''
    #! ${yaegi}/bin/yaegi

    ${builtins.readFile filePath}
  '';
}
