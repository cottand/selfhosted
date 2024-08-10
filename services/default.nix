{ callPackage, writeText, ... }: {
  s-portfolio-stats = callPackage (import ./s-portfolio-stats) { };
}
