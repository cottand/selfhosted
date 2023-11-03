final: prev:
# https://nixos.wiki/wiki/Overlays
let
  pkgs-config = {
    config.allowUnfree = true;
    system = prev.system;
  };
  unstable = import
    # (builtins.fetchGit {
    #   name = "nixpkgs-unstable";
    #   url = "https://github.com/nixos/nixpkgs-channels.git";
    #   ref = "refs/heads/nixpkgs-unstable";
    #   # rev = "60ffc2aa716d0e23e79d989f71bd921a4dc5cc20"; #"502845c3e31ef3de0e424f3fcb09217df2ce6df6"; 
    # })
    (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz") pkgs-config;
in
{
  # absolute latest nomad
  nomad_1_6 = unstable.nomad_1_6;
}
