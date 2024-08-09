{ self, callPackage, nomad, jq, nix, bws, writeShellScriptBin, writeScriptBin, yaegi, ... }: rec {

  #    buildAllImages = callPackage (import ./buildAllImages) {};

  buildYaegiScript = name: filePath: writeScriptBin name ''
    #! ${yaegi}/bin/yaegi
    ${builtins.readFile filePath}
  '';

  # templates a nomad nix file into JSON and calls nomad run on it
  # usage: nixmad path/to/job.nix
  nixmad = writeShellScriptBin "nixmad" ''
    set -e
    ${nix}/bin/nix eval -f $1 --json --show-trace | ${nomad}/bin/nomad run -json -
  '';

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

  allImages = callPackage (import ./allImages) { inherit self; };
}
