with builtins;
let
  # eval = import (fetchurl "https://github.com/zhaofengli/colmena/raw/main/src/nix/hive/eval.nix");
  eval = import ./eval.nix;
  options_nix = (fetchurl "https://github.com/zhaofengli/colmena/raw/main/src/nix/hive/options.nix");
  modules_nix = (fetchurl "https://github.com/zhaofengli/colmena/raw/main/src/nix/hive/modules.nix");
in
  eval { rawHive = import ./hive.nix ; colmenaOptions = import options_nix; colmenaModules = import modules_nix; }
