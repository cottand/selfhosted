# For every image to be built in CI,
# this produces a JSON-formatted file like:
#
#  {
#    <name1>: <image_targz_1>,
#    <name2>: <image_targz_2>,
#    ...etc
#  }
#
# You can build and cat this file to build all images.
{ self, writeText, system, lib, ... }:
let
  services = self.legacyPackages.${system}.services;
  servicesWithImage = lib.attrsets.filterAttrs (_: svc: svc ? "image") services;
  images = with builtins; toJSON (mapAttrs (_: svc: toString svc.image.out) servicesWithImage);
in
writeText "all-images" images
