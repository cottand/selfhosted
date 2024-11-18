{ name, pkgs, lib, config, modulesPath, ... }: {
  imports = [
    "${modulesPath}/virtualisation/google-compute-image.nix"
  ];
  virtualisation.googleComputeImage.diskSize = 3000;


  boot.loader.grub.configurationLimit = 1;

  ## Nomad
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = false;
  };

  services.nomad.settings = {
    datacenter = "nuremberg-gcp";
    client = {
      cpu_total_compute = 2 * 2000;
    };
  };

  # to figure out ARM CPU clock speed in Nomad
  environment.systemPackages = with pkgs; [ dmidecode ];

  system.stateVersion = "24.05";
}

