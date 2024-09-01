{ self, callPackage, nomad, jq, nix, bws, writeShellScriptBin, writeScriptBin, yaegi, ... }: rec {

  # TODO look into https://noogle.dev/f/lib/filesystem/packagesFromDirectoryRecursive


  # templates a nomad nix file into JSON and calls nomad run on it
  # usage: nixmad path/to/job.nix
#  nixmad = writeShellScriptBin "nixmad" ''
#    set -e
#    ${nix}/bin/nix eval -f $1 --json --show-trace | ${nomad}/bin/nomad run -json -
#  '';

    nixmad = callPackage ./nixmad/package.nix {};

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
}
