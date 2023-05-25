{
  nixos-unstable = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  nixos-22-11 = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/22.11.tar.gz";
  nixos-23-11-pre = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.11-pre.tar.gz";
}
