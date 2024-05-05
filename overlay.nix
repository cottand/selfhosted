# https://nixos.wiki/wiki/Overlays
final: prev:
{
  # consul = prev.consul.overrideAttrs {
  #   patches = [
  #     (prev.fetchpatch {
  #       url = "https://patch-diff.githubusercontent.com/raw/hashicorp/consul/pull/20973.patch";
  #       sha256 = "sha256-3LY08gJwZ8DkwBoGVOQEf/JMRc1YLNrpKPWs4qAbR2M=";
  #     })
  #   ];
  # };
}
