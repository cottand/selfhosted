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

    leng = {
      url = "github:cottand/leng/nixos-module";
      inputs.nixpkgs.follows = "nixpkgs23-11";
    };
  };

  outputs = { nixpkgs23-11, cottand, home-manager, ... }:
    let
      overlay = cottand.overlay;
      secretPath = "/home/cottand/dev/selfhosted/secret/";
    in
    {
      colmena = {
        meta = {
          nixpkgs = import nixpkgs23-11 {
            system = "x86_64-linux";
          };
        };

        defaults = { pkgs, lib, name, nodes, ... }: {
          imports = [
            ./machines/${name}/definition.nix
            ./machines/common_config.nix
            ./modules
            home-manager.nixosModules.home-manager
          ];
          nixpkgs.overlays = [ overlay ];
          nixpkgs.system = "x86_64-linux";
          networking.hostName = lib.mkDefault name;

          deployment = {
            replaceUnknownProfiles = lib.mkDefault true;
            buildOnTarget = lib.mkDefault false;
            targetHost = lib.mkDefault "${name}.mesh.dcotta.eu";
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
        };

        cosmo = { name, nodes, ... }: {
          deployment.targetHost = "${name}.vps.dcotta.eu";
          deployment.tags = [ "contabo" "nomad-server" ];
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
        };


        miki = { name, nodes, lib, ... }: {
          deployment.targetHost = "${name}.vps.dcotta.eu";
          nixpkgs.system = lib.mkForce "aarch64-linux";
          deployment.tags = [ "hetzner" "nomad-client" ];
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
        };

        maco = { name, nodes, ... }: {
          deployment.tags = [ "contabo" "nomad-server" ];
          deployment.targetHost = "maco.mesh.dcotta.eu";
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
        };

        elvis = { name, nodes, ... }: {
          deployment.targetHost = "elvis.vps6.dcotta.eu";
          deployment.tags = [ "local" "nomad-client" ];
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
        };

        ziggy = { name, nodes, ... }: {
          imports = [ ];
          deployment.tags = [ "local" "nomad-client" ];
          deployment.targetHost = "${name}.vps6.dcotta.eu"; # TODO CHANGE
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
        };

        ari = { name, nodes, ... }: {
          imports = [ ];
          networking.hostName = name;
          deployment.tags = [ "local" "nomad-server" ];
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
          deployment.targetHost = "192.168.50.145";
        };


        bianco = { name, nodes, ... }: {
          imports = [ ];
          deployment.tags = [ "madrid" "nomad-client" ];
          custom.wireguard."wg-mesh" = {
            enable = true;
            confPath = secretPath + "wg-mesh/${name}.conf";
            port = 55820;
          };
        };
      };
    };
}
