# Collection of services used in this repo.
#
# The source code does not need to live here, but every attribute of this set must return
# the built binary and that itself has to have an extra `.image` attribute, which is
# the OCI image to be built and run.
{ callPackage, lib, util, ... }:
let
  inherit (lib) sources fileset;
in
{
  s-web-portfolio = callPackage (import ./s-web-portfolio) { };

  s-portfolio-stats = callPackage (import ./s-portfolio-stats) { };
}
