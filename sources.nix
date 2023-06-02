{
  nixos-unstable = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  nixos-22-11 = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/22.11.tar.gz";
  nixos-23-11-pre = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.11-pre.tar.gz";
  nixos-23-05-beta = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/23.05-beta.tar.gz";
  nixos-23-05-cottand-custom = builtins.fetchTarball "https://github.com/Cottand/nixpkgs/archive/23.05-custom.tar.gz";
}
