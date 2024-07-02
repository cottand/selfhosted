inputs@{ self, nixpkgs, cottand, home-manager, utils, nixpkgs-master, attic, overlays, ... }:
let
  secretPath = "/Users/nico/dev/cottand/selfhosted/secret/";
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
      bianco = "10.10.0.2";

      hez1 = "10.10.11.1";
      hez2 = "10.10.12.1";
      hez3 = "10.10.13.1";
    };
  };

  defaults = { pkgs, lib, name, nodes, meta, ... }: {
    imports = [
      ./machines/${name}/definition.nix
      ./machines/_default
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
  };

  cosmo = { name, nodes, ... }: {
    deployment.targetHost = "${name}.vps.dcotta.eu";
    deployment.tags = [ "contabo" "nomad-server" "vault" ];
    vaultNode.enable = true;
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

  hez1 = { name, nodes, ... }: {
    deployment.tags = [ "hetzner" ];
    deployment.targetHost = "${name}.vps.dcotta.com";
  };
  hez2 = { name, nodes, ... }: {
    deployment.tags = [ "hetzner" ];
    deployment.targetHost = "${name}.vps.dcotta.com";
  };
  hez3 = { name, nodes, ... }: {
    deployment.tags = [ "hetzner" ];
    deployment.targetHost = "${name}.vps.dcotta.com";
  };
}
