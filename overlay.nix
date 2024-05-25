# https://nixos.wiki/wiki/Overlays
final: prev:
{
#   consul = prev.consul.overrideAttrs {
#   vendorHash = prev.lib.fakeSha256;
#     patches = [
##       (prev.fetchpatch {
##         url = "https://patch-diff.githubusercontent.com/raw/Cottand/consul/pull/1.patch";
##         sha256 = "sha256-wqTwYo96ZDgImxi4pWiOMYBKP4mg/A0iDCh/C9ROqQo=";
##       })
#     ];
#   };
}
