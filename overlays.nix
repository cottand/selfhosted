final: prev:
# https://nixos.wiki/wiki/Overlays
let
  master = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz") pkgs-config;
  unstable = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/unstable.tar.gz") pkgs-config;
  pkgs-config = {
    config.allowUnfree = true;
    system = prev.system;
  };
in
{
  # absolute latest nomad
  nomad_1_6 = master.nomad_1_6;

  # nix language server
  nixd = unstable.nixd;
}
