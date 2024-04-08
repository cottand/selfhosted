# https://nixos.wiki/wiki/Overlays
final: prev:
{

  # consul =
  #   let
  #     patch = prev.fetchpatch {
  #       url = "https://github.com/Cottand/consul/commit/f3aeab4e38b04a3ed637c0b5a67ed92dfffb9c5a.patch";
  #       sha256 = "sha256-pG5NbKud8GkmbSD4/Z79qrftdp0upBydWjbkU73E+cc=";
  #     };
  #   in
  #   prev.consul.overrideAttrs {
  #     patches = [ patch ];
  #   };
}
