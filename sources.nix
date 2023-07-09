{
  nixos-unstable = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  nixos-22-11 = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/22.11.tar.gz";
  nixos-23-05-cottand-custom = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/23.05-custom.tar.gz";
  nixos-23-05-cottand-3 = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/refs/tags/23.05-cottand-3.tar.gz";
  nixos-23-05-cottand-4 = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/refs/tags/23.05-cottand-4.tar.gz";
  nixos-23-05-cottand-6 = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/refs/tags/23.05-cottand-6.tar.gz";
  nixos-local-dev = "/Users/nico/dev/nixpkgs";
}
