{ callPackage, ... }: {
  name = "services";

  portfolioStats = callPackage (import ./portfolioStats) { };
}
