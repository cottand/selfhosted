{ callPackage, writeText, ... }: {
  portfolioStats = callPackage (import ./portfolioStats) { };
}
