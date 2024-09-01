{ job, version, ... }:
let
  jobType = builtins.typeOf job;
in
if jobType == "lambda" then (job { inherit version; }) else job
