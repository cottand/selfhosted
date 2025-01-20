{ self, pkgs, callPackage, jq, bws, writeShellScriptBin, get-external-imports, ... }: rec {

  # TODO look into https://noogle.dev/f/lib/filesystem/packagesFromDirectoryRecursive


  all-images = callPackage ./all-images { inherit self; };
  gen-protos = callPackage ./gen-protos.nix { inherit self; };
  nixmad = callPackage ./nixmad.nix { inherit self; };
  shipper = callPackage ./shipper.nix { inherit self; };

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

  start-gh-runner = writeShellScriptBin "start-gh-runner" ''
    set -e

    ${pkgs.github-runner}/bin/config.sh --url $GH_RUNNER_REPO --token $GH_RUNNER_TOKEN
    ${pkgs.github-runner}/run.sh
  '';

  inherit get-external-imports;
}
