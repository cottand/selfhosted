{ self, writeText, system, ... }:
let
  services = self.legacyPackages.${system}.services;
  images = with builtins; toJSON (mapAttrs  (_: svc: toString svc.image.out) services);
in writeText "all-images" images
