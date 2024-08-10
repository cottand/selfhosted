# Collection of services used in this repo.
#
# The source code does not need to live here, but every attribute of this set must return
# the built binary and that itself has to have an extra `.image` attribute, which is
# the OCI image to be built and run.
{ callPackage, writeText, ... }: {
  s-portfolio-stats = callPackage (import ./s-portfolio-stats) { };
}
