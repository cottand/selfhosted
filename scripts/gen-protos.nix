{ writeShellScriptBin, self, system, util, ... }:
let
  services = builtins.attrNames self.legacyPackages.${system}.services;
  perServiceCommand = map
    (name:
      ''
        generated="${util.protosFor name}/def.pb.go"
        if [ -f "$generated" ]; then
          mkdir -p services/lib/proto/${name}
          cat $generated >> services/lib/proto/${name}/def.pb.go
        fi
      ''
    )
    services;
  concatted = builtins.concatStringsSep "\n" perServiceCommand;

in
writeShellScriptBin "gen-protos" ''
  current=$(basename $PWD)
  if [ "$current" != selfhosted ]; then
    echo "You're not running in selfhosted"
    exit -1
  fi

  proto="services/lib/proto"
  mkdir -p $proto

  ${concatted}
''
