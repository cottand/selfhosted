{ pkgs, modulesPath, lib, ... }: {
  imports = [
    "${modulesPath}/virtualisation/google-compute-image.nix"
  ];
#  virtualisation.googleComputeImage.diskSize = 3000;


  ## Nomad
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = false;
  };

  services.nomad.settings = {
    datacenter = "nuremberg-gcp";
    client.meta."cloud-vendor" = "gcp";
  };

  # to figure out ARM CPU clock speed in Nomad
  environment.systemPackages = with pkgs; [ dmidecode ];

  services.openssh.openFirewall = lib.mkForce true;

  system.stateVersion = "24.05";
}

