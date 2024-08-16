{ writeShellScriptBin, self, system, util, ... }:
let
  services = builtins.attrNames self.legacyPackages.${system}.services;
  perServiceCommand = map
    (name: (if (self.legacyPackages.${system}.services.${name} ? "protos") then
      ''
        generated=$(nix build .#services.${name}.protos --no-link --print-out-paths -L)
        rm services/lib/proto/${name}/* || 0
        mkdir -p services/lib/proto/${name}

        cat $generated/def.pb.go >> services/lib/proto/${name}/def.pb.go
        cat $generated/def_grpc.pb.go >> services/lib/proto/${name}/def_grpc.pb.go
      '' else ""
    ))
    services;
  concatted = builtins.concatStringsSep "\n" perServiceCommand;

in
writeShellScriptBin "gen-protos" ''
  current=$(basename $PWD)
  if [ "$current" != selfhosted ]; then
    echo "You're not running this in selfhosted/ !"
    exit -1
  fi

  proto="services/lib/proto"
  mkdir -p $proto

  ${concatted}
''
