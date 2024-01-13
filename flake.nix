{
  inputs = {
    nixpkgs23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/master";

    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs23-11";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs23-11";
    };
  };

  outputs = { nixpkgs23-11, nixpkgs-unstable, cottand, home-manager, ... }:
    let
      overlay = cottand.overlay;
      secretPath = "/home/cottand/dev/selfhosted/secret/";
    in
    {
      colmena = {
        meta = {
          nixpkgs = import nixpkgs23-11 { system = "x86_64-linux"; };
          specialArgs.secretPath = secretPath;
          specialArgs.meta.ip.mesh = {
            cosmo = "10.10.0.1";
            elvis = "10.10.1.1";
            maco = "10.10.2.1";
            ari = "10.10.3.1";
            miki = "10.10.4.1";
            ziggy = "10.10.5.1";
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
          nixpkgs.overlays = [ overlay ];
          nixpkgs.system = "x86_64-linux";
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
        };

        cosmo = { name, nodes, ... }: {
          # deployment.targetHost = "${name}.vps.dcotta.eu";
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
          vaultNode.enable = true;
        };


        miki = { name, nodes, lib, ... }: {
          # deployment.targetHost = "${name}.vps.dcotta.eu";
          nixpkgs.system = lib.mkForce "aarch64-linux";
          deployment.tags = [ "hetzner" "nomad-server" "vault" ];
          vaultNode.enable = true;

        };

        maco = { name, nodes, ... }: {
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
          # deployment.targetHost = "maco.mesh.dcotta.eu";
          # deployment.targetHost = "${name}.vps6.dcotta.eu";
          vaultNode.enable = true;
        };

        elvis = { name, nodes, ... }: {
          deployment.tags = [ "local" "nomad-client" ];
        };

        ziggy = { name, nodes, ... }: {
          imports = [ ];
          deployment.tags = [ "local" "nomad-client" ];
        };

        ari = { name, nodes, ... }: {
          imports = [ ];
          networking.hostName = name;
          deployment.tags = [ "local" "nomad-client" ];
        };

        bianco = { name, nodes, ... }: {
          imports = [ ];
          deployment.tags = [ "madrid" "nomad-client" ];
        };
      };

      devShells.x86_64-linux.default =
        let
          pkgs = import nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        in
        pkgs.mkShell {
          name = "selfhosted-dev";
          packages = with pkgs; [ terraform colmena fish vault ];
          shellHook = "fish && exit";
        };
    };
}
