inputs@{ self, srvos, nixpkgs, cottand, home-manager, utils, attic, overlays, ... }:
let
  secretPath = "/Users/nico/dev/cottand/selfhosted/secret/";

  mkNodePool = { names, module, ... }: builtins.listToAttrs (builtins.map
    (name: {
      inherit name;
      value = module;
    })
    names);
in
{
  meta = {
    nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
    specialArgs.secretPath = secretPath;
    specialArgs.flakeInputs = inputs;
  };

  defaults = { pkgs, lib, name, nodes, meta, config, ... }: {
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
      config.permittedInsecurePackages = [ "broadcom-sta-6.30.223.271-59-6.12.57" ];
    };
    deployment.tags = [ config.nixpkgs.system ];
    deployment.targetUser = "colmena";
  };

  cosmo = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "contabo" "nomad-server" ];
  };

  miki = { name, nodes, lib, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "contabo" "nomad-server" ];
  };

  ari = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "nomad-client" ];
  };

  xps2 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "nomad-client" ];
  };

  bianco = { name, nodes, lib, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "madrid" "nomad-client" ];
  };

  hez1 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "hetzner" ];
  };
  hez2 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "hetzner" ];
  };
  hez3 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "hetzner" ];
  };
  macMini1 = { name, nodes, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" "macmini" ];
  };
  imac = { name, ... }: {
    imports = [ ./machines/${name}/definition.nix ];
    deployment.tags = [ "local" ];
  };
}
  // (mkNodePool {
  names = with builtins; fromJSON (readFile "${self}/terraform/metal/oci_control.json");
  module = {
    # hqsw has 1 core not 2
    imports = [ ./machines/ociControlWorker srvos.nixosModules.server ];
    deployment.tags = [ "oci-control" ];
    deployment.buildOnTarget = false;
  };
})
