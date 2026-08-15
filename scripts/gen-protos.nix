{ writeShellScriptBin, self, stdenv, util, ... }:
let
  system = stdenv.hostPlatform.system;
  services = builtins.attrNames self.legacyPackages.${system}.services;
  mkProtoGenCommandFor = name: (if (self.legacyPackages.${system}.services.${name} ? "protos") then
    ''
      generated=$(nix build .#services.${name}.protos --no-link --print-out-paths -L)
      rm dev-go/lib/proto/${name}/* || true
      mkdir -p dev-go/lib/proto/${name}

      [ -f "$generated/def.pb.go" ] && cat "$generated/def.pb.go" >> dev-go/lib/proto/${name}/def.pb.go
      [ -f "$generated/def_grpc.pb.go" ] && cat "$generated/def_grpc.pb.go" >> dev-go/lib/proto/${name}/def_grpc.pb.go
      [ -f "$generated/def_devgo.pb.go" ] && cat "$generated/def_devgo.pb.go" >> dev-go/lib/proto/${name}/def_devgo.pb.go
    '' else ""
  );
  concatted = builtins.concatStringsSep "\n" (map mkProtoGenCommandFor services);

in
writeShellScriptBin "gen-protos" ''
  current=$(basename $PWD)
  if [ "$current" != selfhosted ]; then
    echo "You're not running this in selfhosted/ !"
    exit -1
  fi

  proto="dev-go/lib/proto"
  mkdir -p $proto

  # if there is an arg, that is the service's name
  if [ -n "$1" ]; then
    generated=$(nix build .#services."$1".protos --no-link --print-out-paths -L)
    rm dev-go/lib/proto/"$1"/* || true
    mkdir -p dev-go/lib/proto/"$1"

    [ -f "$generated/def.pb.go" ] && cat "$generated/def.pb.go" >> dev-go/lib/proto/"$1"/def.pb.go
    [ -f "$generated/def_grpc.pb.go" ] && cat "$generated/def_grpc.pb.go" >> dev-go/lib/proto/"$1"/def_grpc.pb.go
    [ -f "$generated/def_devgo.pb.go" ] && cat "$generated/def_devgo.pb.go" >> dev-go/lib/proto/"$1"/def_devgo.pb.go
    exit 0;
  fi

  ${concatted}
''
