{ nodes, ... }:

{
  # emulate ARM - see https://colmena.cli.rs/unstable/examples/multi-arch.html
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  programs.ssh.extraConfig = ''
    Host *.mesh.dcotta.eu
      User root
      PubkeyAcceptedKeyTypes ssh-ed25519
      ServerAliveInterval 60
      IPQoS throughput
      IdentityFile /home/cottand/.ssh/id_ed25519
  '';
  nix.buildMachines =
    let
      arm = "aarch64-linux";
      x86_64 = "x86_64-linux";
      eligible = with builtins; attrValues (mapAttrs (name: system: { inherit name system; }) {
        maco = x86_64;
        cosmo = x86_64;
        miki = arm;
      });
    in
    builtins.map
      (
        { name, system }: {
          inherit system;
          hostName = "${name}.mesh.dcotta.eu";
          protocol = "ssh-ng";
          # if the builder supports building for multiple architectures, 
          # replace the previous line by, e.g.,
          # systems = ["x86_64-linux" "aarch64-linux"];
          maxJobs = 2;
          speedFactor = 2;
          supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
          mandatoryFeatures = [ ];
        }
      ) eligible
  ;

  nix.distributedBuilds = true;
  # optional, useful when the builder has a faster internet connection than yours
  nix.extraOptions = ''
    		builders-use-substitutes = true
    	'';
}
