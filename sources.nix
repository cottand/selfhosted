builtins.mapAttrs (name: value: import value) {
  nixos-unstable = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  nixos-22-11 = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/22.11.tar.gz";
  nixos-23-05 = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05.tar.gz";
  nixos-23-05-cottand-6 = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/refs/tags/23.05-cottand-6.tar.gz";
  nixos-23-05-cottand-7 = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/refs/tags/23.05-cottand-7.tar.gz";
  nixos-local-dev = /Users/nico/dev/nixpkgs;

  nixos-23-05-2 = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/refs/tags/23.05.2.tar.gz";
}
