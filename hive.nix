inputs@{ self, nixpkgs, cottand, home-manager, utils, nixpkgs-master, attic, overlays, ... }:
let
  secretPath = "/Users/nico/dev/cottand/selfhosted/secret/";

  mkNodePool = { tags ? [ ], names, nodeType, ... }: builtins.listToAttrs (builtins.map
    (name: rec {
      inherit name;
      value = { ... }: {
        deployment.tags = tags;
        deployment.targetHost = "${name}.vps.dcotta.com";
        nodeType.${nodeType} = true;
      };
    })
    names);


in
{
  meta = {
    nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
    specialArgs.secretPath = secretPath;
    specialArgs.flakeInputs = inputs;
    specialArgs.meta.ip.mesh = {
      cosmo = "10.10.0.1";
      maco = "10.10.2.1";
      ari = "10.10.3.1";
      miki = "10.10.4.1";
      xps2 = "10.10.6.1";
      bianco = "10.10.11.2";

      hez1 = "10.10.11.1";
      hez2 = "10.10.12.1";
      hez3 = "10.10.13.1";
    };
  };

  defaults = { pkgs, lib, name, nodes, meta, ... }: {
    imports = [
      ./machines/_default
      ./machines/modules
      home-manager.nixosModules.home-manager
      cottand.nixosModules.seaweedBinaryCache
      cottand.nixosModules.dcottaRootCa
    ];
    nixpkgs = {
      inherit overlays;
      system = lib.mkDefault "x86_64-linux";
      config.allowUnfree = true;
    };
  };

  cosmo = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.buildOnTarget = false;
    deployment.targetHost = "${name}.vps.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" "vault" ];
  };

  miki = { name, nodes, lib, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.targetHost = "${name}.mesh.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" "vault" ];
  };

  ari = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    networking.hostName = name;
    deployment.tags = [ "local" "nomad-client" ];
  };

  xps2 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    networking.hostName = name;
    deployment.tags = [ "local" "nomad-client" ];
  };

  bianco = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "madrid" "nomad-client" ];
  };

  hez1 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    vaultNode.enable = true;
    deployment.buildOnTarget = false;
    deployment.tags = [ "hetzner" ];
    deployment.targetHost = "${name}.vps.dcotta.com";
  };
  hez2 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    vaultNode.enable = true;
    deployment.buildOnTarget = false;
    deployment.tags = [ "hetzner" ];
    deployment.targetHost = "${name}.vps.dcotta.com";
  };
  hez3 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    vaultNode.enable = true;
    deployment.buildOnTarget = false;
    deployment.tags = [ "hetzner" ];
    deployment.targetHost = "${name}.vps.dcotta.com";
  };
} // (mkNodePool {
  names = [ ];
  nodeType = "ociPool1Worker";
})
