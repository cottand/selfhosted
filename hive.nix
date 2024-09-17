inputs@{ self, nixpkgs, cottand, home-manager, utils, nixpkgs-master, attic, overlays, ... }:
let
  secretPath = "/Users/nico/dev/cottand/selfhosted/secret/";

  mkNodePool = { tags ? [ ], names, imports, ... }: builtins.listToAttrs (builtins.map
    (name: rec {
      inherit name;
      value = { ... }: {
        inherit imports;
        deployment.tags = tags;
        deployment.targetHost = "${name}.vps.dcotta.com";
      };
    })
    names);


in
{
  meta = {
    nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
    specialArgs.secretPath = secretPath;
    specialArgs.flakeInputs = inputs;
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
    deployment.tags = [ "contabo" "nomad-server" "vault" ];
  };

  miki = { name, nodes, lib, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "contabo" "nomad-server" "vault" ];
  };

  ari = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "nomad-client" ];
  };

  xps2 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
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
  };
  hez2 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    vaultNode.enable = true;
    deployment.buildOnTarget = false;
    deployment.tags = [ "hetzner" ];
  };
  hez3 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    vaultNode.enable = true;
    deployment.buildOnTarget = false;
    deployment.tags = [ "hetzner" ];
  };
} // (mkNodePool {
  names = [ "inst-uhudp-control" "inst-abrey-control" "inst-gb5kd-control" ];
  imports = [ ./machines/ociControlWorker ];
  tags = [ "oci-control" ];
})
