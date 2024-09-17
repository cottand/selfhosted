{ name, pkgs, lib, config, ... }: {
  imports = [ ./hardware-configuration.nix ];

  nixpkgs.system = "aarch64-linux";

  system.stateVersion = "23.11";
}

