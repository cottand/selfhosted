{ self, writeShellScriptBin, writeText, lib, ... }:
let
  services = self.legacyPackages.x86_64-linux.services;
  images = with builtins; lib.strings.concatMapStrings (svc: "${svc.image.out}\n") (attrValues  services);
in
writeShellScriptBin "printAllImages" ''
  set -e
  cat ${writeText "images" images}
''
