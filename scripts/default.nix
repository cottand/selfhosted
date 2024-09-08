{ self, callPackage, jq, bws, writeShellScriptBin, get-external-imports, ... }: rec {

  # TODO look into https://noogle.dev/f/lib/filesystem/packagesFromDirectoryRecursive


  # templates a nomad nix file into JSON and calls nomad run on it
  # usage: nixmad --help
  nixmad = callPackage ./nixmad.nix { inherit self; };

  # fetches a secret from bitwarden-secret by ID
  # usage: bws-get <ID>
  bws-get = writeShellScriptBin "bws-get" ''
    set -e
    ${bws}/bin/bws secret get $1 | ${jq}/bin/jq -r '.value'
  '';

  # returns a secret from the MacOS keychain fromatted as JSON for use in TF
  # usage: keychain-get <SERVICE>
  # returns {"value": "<SECRET>"}
  keychain-get = writeShellScriptBin "keychain-get" ''
    set -e
    SECRET=$(/usr/bin/security find-generic-password -gw -l "$1")
    ${jq}/bin/jq -n --arg value "$SECRET" '{ "value": $value }'
  '';

  all-images = callPackage ./all-images { inherit self; };

  gen-protos = callPackage ./gen-protos.nix { inherit self; };

  inherit get-external-imports;
}
