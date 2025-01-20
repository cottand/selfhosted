{ pkgs, lib, name, nodes, meta, secretPath, flakeInputs, ... }: {

  imports = [
    ./common_config.nix
    ./tailscale.nix
  ];

  networking.hostName = name;

  deployment = {
    replaceUnknownProfiles = lib.mkDefault true;
    buildOnTarget = lib.mkDefault false;
    targetHost = lib.mkDefault "${name}.golden-dace.ts.net";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.cottand = {
      imports = with flakeInputs.cottand.homeManagerModules; [ cli ];
      home.stateVersion = "22.11";
    };
    users.root = {
      imports = with flakeInputs.cottand.homeManagerModules; [ cli ];
      home.stateVersion = "22.11";
    };
  };

  consulNode.enable = lib.mkDefault true;
}
