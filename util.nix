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
      svc = "${cleanSourceForGoService serviceName}/services/${serviceName}";
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

  buildYaegiScript = name: filePath: writeScriptBin name ''
    #! ${yaegi}/bin/yaegi

    ${builtins.readFile filePath}
  '';
}
