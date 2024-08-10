{ callPackage, writeText, ... }: {
  portfolio-stats = callPackage (import ./portfolio-stats) { };
}
