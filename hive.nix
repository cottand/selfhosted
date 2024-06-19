inputs@{ self, nixpkgs, cottand, home-manager, utils, nixpkgs-master, attic, ... }:
 let
      secretPath = "/Users/nico/dev/cottand/selfhosted/secret/";
in
 {
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
          nixpkgs = {
            inherit overlays;
            system = lib.mkDefault "x86_64-linux";
            config.allowUnfree = true;
          };
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
          deployment.targetHost = "${name}.mesh.dcotta.eu";
          # deployment.targetHost = "";
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
          vaultNode.enable = true;
          consulNode.server = true;
        };

        maco = { name, nodes, ... }: {
          deployment.tags = [ "contabo" "nomad-server" "vault" ];
           deployment.targetHost = "${name}.vps.dcotta.eu";
          vaultNode.enable = true;
          consulNode.server = true;
        };

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
}