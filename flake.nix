{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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

    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, cottand, home-manager, utils, ... }:
    let
      overlays = [ (import ./overlay.nix) ];
      secretPath = "/Users/nico/dev/cottand/selfhosted/secret/";
    in
    {
      colmena = {
        meta = {
          nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
          specialArgs.secretPath = secretPath;
          specialArgs.meta.ip.mesh = {
            cosmo = "10.10.0.1";
            elvis = "10.10.1.1";
            maco = "10.10.2.1";
            ari = "10.10.3.1";
            miki = "10.10.4.1";
            ziggy = "10.10.5.1";
            xps2 = "10.10.6.1";
            bianco = "10.10.0.2";
          };
        };

        defaults = { pkgs, lib, name, nodes, meta, ... }: {
          imports = [
            ./machines/${name}/definition.nix
            ./machines/common_config.nix
            ./modules
            home-manager.nixosModules.home-manager
            cottand.nixosModules.seaweedBinaryCache
            cottand.nixosModules.dcottaRootCa
          ];
          nixpkgs.overlays = overlays;
          nixpkgs.system = lib.mkDefault "x86_64-linux";
          networking.hostName = lib.mkDefault name;

          deployment = {
            replaceUnknownProfiles = lib.mkDefault true;
            buildOnTarget = lib.mkDefault true;
            targetHost = lib.mkDefault meta.ip.mesh."${name}";
          };

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.cottand = {
              imports = with cottand.homeManagerModules; [ cli ];
              home.stateVersion = "22.11";
            };
            users.root = {
              imports = with cottand.homeManagerModules; [ cli ];
              home.stateVersion = "22.11";
            };
          };

          # mesh VPN
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
          consulNode.enable = true;
        };

        cosmo = { name, nodes, ... }: {
          deployment.targetHost = "${name}.vps.dcotta.eu";
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
          vaultNode.enable = true;

          consulNode.server = true;
        };

        miki = { name, nodes, lib, ... }: {
          deployment.targetHost = "${name}.vps.dcotta.eu";
          # deployment.targetHost = "";
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
          vaultNode.enable = true;
          consulNode.server = true;
        };

        maco = { name, nodes, ... }: {
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
          # deployment.targetHost = "${name}.vps6.dcotta.eu";
          vaultNode.enable = true;
          consulNode.server = true;
        };

        # elvis = { name, nodes, ... }: {
        #   deployment.tags = [ "local" "nomad-client" ];
        # };

        # ziggy = { name, nodes, ... }: {
        #   deployment.tags = [ "local" "nomad-client" ];
        # };

        ari = { name, nodes, ... }: {
          networking.hostName = name;
          deployment.tags = [ "local" "nomad-client" ];
          consulNode.server = true;
        };

        xps2 = { name, nodes, ... }: {
          consulNode.server = true;
          networking.hostName = name;
          deployment.tags = [ "local" "nomad-client" ];
        };

        bianco = { name, nodes, ... }: {
          deployment.tags = [ "madrid" "nomad-client" ];
        };
      };
    } // (utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        x86DarwinPkgs = import nixpkgs { system = "x86_64-darwin"; config.allowUnfree = true; };
        roachdb = if system == "aarch64-darwin" then x86DarwinPkgs.cockroachdb else pkgs.cokcroachdb;
        devPackages = with pkgs; [
          # roachdb
          terraform
          colmena
          fish
          vault
          nomad_1_7
          bitwarden-cli
          consul
          seaweedfs
          wander
          self.packages.${system}.nixmad
        ];
      in
      {
        packages.nixmad = pkgs.writeShellScriptBin "nixmad" ''
          ${pkgs.nix}/bin/nix eval -f $1 --json --show-trace | ${pkgs.nomad}/bin/nomad run -json -
        '';

        devShells.default = pkgs.mkShell {
          name = "selfhosted-dev";
          packages = devPackages;
          shellHook = ''fish --init-command 'abbr -a weeds "nomad alloc exec -i -t -task seaweed-filer -job seaweed-filer weed shell -master 10.10.4.1:9333" ' && exit'';

          NOMAD_ADDR = "https://10.10.4.1:4646";
          VAULT_ADDR = "https://10.10.2.1:8200";
          # VAULT_ADDR = "https://vault.mesh.dcotta.eu:8200";
        };

        formatter = pkgs.writeShellScriptBin "fmt" ''
          ${pkgs.nomad}/bin/nomad fmt
          ${pkgs.terraform}/bin/terraform fmt
        '';
      }
    ));
}
