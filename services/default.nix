# Collection of services used in this repo.
#
# The source code does not need to live here, but every attribute of this set must return
# the built binary and that itself has to have an extra `.image` attribute, which is
# the OCI image to be built and run. There may optionally be an additional `.protos` attribute
# which points to the codegenerated proto code for that specific service.
#
{ callPackage, ... }:
{
  s-rpc-portfolio-stats = callPackage ./s-rpc-portfolio-stats/package.nix { };

  s-web-github = callPackage ./s-web-github/package.nix { };
  s-web-portfolio = callPackage ./s-web-portfolio/package.nix { };

  services-go = callPackage ./package.nix { };
}
