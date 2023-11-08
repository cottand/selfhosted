{ pkgs, ... }:
{
  users.users.cottand.packages = [
    pkgs.jetbrains.idea-ultimate
    pkgs.jetbrains.goland
  ];



}
