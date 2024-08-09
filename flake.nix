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
      withScripts = final: prev: {
       scripts = self.legacyPackages.${prev.system}.scripts;
      };
      overlays = [ (import ./overlay.nix) withScripts newVault attic.overlays.default ];
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
      rec {

        legacyPackages.services = (import ./services) pkgs;
        legacyPackages.scripts = (import ./scripts) (pkgs // {inherit self; });

        packages = legacyPackages.scripts;

        devShells.default = pkgs.mkShell {
          name = "selfhosted-dev";
          packages = with pkgs; with self.packages.${system}; [
            # roachdb
            terraform
            colmena
            fish
            vault
            nomad_1_8
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
            fish --init-command 'abbr -a weeds "nomad alloc exec -i -t -task seaweed-filer -job seaweed-filer weed shell -master 10.10.11.1:9333" ' && exit'';

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
