{ meta, name, ... }:
let selfIp = meta.ip.mesh.${name};
in
{
  environment.etc = {
    "hydraBuilders".text = (builtins.readFile ./defaultNomadConfig/client.hcl);
  };
  services.hydra = {
    enable = true;
    port = 3001;
    listenHost = selfIp;
    hydraURL = "http://${selfIp}:3001"; # externally visible URL
    notificationSender = "hydra@localhost"; # e-mail of hydra service
    # a standalone hydra will require you to unset the buildMachinesFiles list to avoid using a nonexistant /etc/nix/machines
    buildMachinesFiles = [ ];
    # you will probably also want, otherwise *everything* will be built from scratch
    useSubstitutes = true;
    minimumDiskFree = 10; # Gb
    minimumDiskFreeEvaluator = 10; # Gb
  };
}
