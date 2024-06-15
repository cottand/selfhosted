{ pkgs, ... }: {
  seaweedfs = pkgs.callPackage ./seaweedfs.nix { };
}
