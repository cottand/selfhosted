# codegenerates CI, using this repo's flake structure to know what to codegen
{self, writeText, ...}:
 let
  in
   writeText "gh-ci.json" (builtins.toJSON {
        name = "gh-ci-generated";
        on.push.branches = "master";
        env = {
          REGISTRY = "ghcr.io";
        };
        jobs = {
            hello-world = {
                runs-on = "ubuntu-latest";
                steps = [
                {
                    run = '' echo "Hello CI world!" '';
                }
                ];
            };
        };
   })