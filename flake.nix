{
  inputs = {
    nixpkgs23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs23-05-pinned.url = "github:NixOS/nixpkgs/d2e4de209881b38392933fabf303cde3454b0b4c";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:cottand/nixpkgs/nomad-172";
    cottand = {
      url = "github:cottand/home-nix";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs23-11";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    leng.url = "github:cottand/leng/nixos-module";
    leng.inputs.nixpkgs.follows = "nixpkgs23-11";
  };

  outputs = inputs@{ nixpkgs23-11, nixpkgs23-05-pinned, cottand, home-manager, nixos-hardware, leng, ... }:
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

          nodeNixpkgs = {
            nico-xps = import nixpkgs23-11 {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
          };
        };

        defaults = { pkgs, lib, name, nodes, ... }: {
          imports = [
            ./machines/${name}/definition.nix
            ./machines/common_config.nix
            ./modules
          ];
          nixpkgs.overlays = [ overlay ];
          nixpkgs.system = "x86_64-linux";
          networking.hostName = lib.mkDefault name;
          deployment = {
            replaceUnknownProfiles = lib.mkDefault true;
            buildOnTarget = lib.mkDefault false;
            targetHost = lib.mkDefault "${name}.mesh.dcotta.eu";
          };
        };

        nico-xps = { name, nodes, ... }: {
          imports = [
            home-manager.nixosModules.home-manager
            nixos-hardware.nixosModules.dell-xps-13-9300
            # leng.nixosModules.default
          ];
          # TEMP?
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            users.cottand = cottand.home;
          };

          deployment = {
            # Allow local deployment with `colmena apply-local`
            allowLocalDeployment = true;

            # Disable SSH deployment. This node will be skipped in a
            # normal`colmena apply`.
            targetHost = null;
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

        # ari = { name, nodes, ... }: {
        #   imports = [
        #     ./machines/${name}/definition.nix
        #   ];
        #   networking.hostName = name;
        #   deployment.tags = [ "local" "nomad-server" ];
        #   custom.wireguard."wg-mesh" = {
        #     enable = true;
        #     confPath = secretPath + "wg-mesh/${name}.conf";
        #     port = 55820;
        #   };
        #   deployment.targetHost = "192.168.1.44";
        # };

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

        bianco = { name, nodes, ... }: {
          imports = [];
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
