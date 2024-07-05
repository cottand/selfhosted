{ pkgs, lib, name, nodes, meta, secretPath, flakeInputs, ... }: {

  imports = [
    ./common_config.nix
  ];

  networking.hostName = lib.mkDefault name;

  deployment = {
    replaceUnknownProfiles = lib.mkDefault true;
    buildOnTarget = lib.mkDefault false;
    targetHost = lib.mkDefault meta.ip.mesh."${name}";
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

  # mesh VPN
  custom.wireguard = lib.mkDefault {
    "wg-mesh" = {
      enable = true;
      confPath = secretPath + "wg-mesh/${name}.conf";
      port = 55820;
    };
  };
  consulNode.enable = lib.mkDefault true;
}
