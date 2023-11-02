final: prev:
# https://nixos.wiki/wiki/Overlays
let
  sources = (import ./sources.nix);
  unstable = sources.nixos-unstable {};
in
{
  nomad_1_6 = unstable.nomad_1_6;
#   nomad = final.nomad_1_6;
}
