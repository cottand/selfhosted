{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";

    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs-unstable.follows = "nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    attic = {
      url = "github:zhaofengli/attic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, cottand, home-manager, utils, nixpkgs-master, attic, ... }:
    let
      newVault = final: prev: {
        vault-bin = (import nixpkgs-master { system = prev.system; config.allowUnfree = true; }).vault-bin;
      };
      overlays = [ (import ./overlay.nix) newVault attic.overlays.default ];
    in
    {
      colmena = (import ./hive.nix) (inputs // { inherit overlays; });
    } // (utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
      in
      {
        # templates a nomad nix file into JSON and calls nomad run on it
        # usage: nixmad path/to/job.nix
        packages.nixmad = pkgs.writeShellScriptBin "nixmad" ''
          set -e
          ${pkgs.nix}/bin/nix eval -f $1 --json --show-trace | ${pkgs.nomad}/bin/nomad run -json -
        '';

        # fetches a secret from bitwarden-secret by ID
        # usage: bws-get <ID>
        packages.bws-get = pkgs.writeShellScriptBin "bws-get" ''
          set -e
          ${pkgs.bws}/bin/bws secret get $1 | ${pkgs.jq}/bin/jq -r '.value'
        '';

        # returns a secret from the MacOS keychain fromatted as JSON for use in TF
        # usage: keychain-get <SERVICE>
        # returns {"value": "<SECRET>"}
        packages.keychain-get = pkgs.writeShellScriptBin "keychain-get" ''
          set -e
          SECRET=$(/usr/bin/security find-generic-password -gw -l "$1")
          ${pkgs.jq}/bin/jq -n --arg value "$SECRET" '{ "value": $value }'
        '';

        legacyPackages.images = (import ./images { inherit pkgs; });

        devShells.default = pkgs.mkShell {
          name = "selfhosted-dev";
          packages = with pkgs; with self.packages.${system}; [
            # roachdb
            terraform
            colmena
            fish
            vault
            nomad_1_7
            consul
            seaweedfs
            wander
            bws

            pkgs.attic

            go

            nixmad
            bws-get
            keychain-get
          ];
          shellHook = ''
            export BWS_ACCESS_TOKEN=$(security find-generic-password -gw -l "bitwarden/secret/m3-cli")
            fish --init-command 'abbr -a weeds "nomad alloc exec -i -t -task seaweed-filer -job seaweed-filer weed shell -master 10.10.4.1:9333" ' && exit'';

          NOMAD_ADDR = "https://10.10.11.1:4646";
          #          VAULT_ADDR = "https://10.10.2.1:8200";
          VAULT_ADDR = "https://vault.mesh.dcotta.eu:8200";
        };

        formatter = pkgs.writeShellScriptBin "fmt" ''
          ${pkgs.nomad}/bin/nomad fmt
          ${pkgs.terraform}/bin/terraform fmt
        '';
      }
    ));
}
