{ name, pkgs, lib, config, ... }: {
  imports = [ ./hardware-configuration.nix ];

  nixpkgs.system = "aarch64-linux";

  # https://github.com/NixOS/nixpkgs/issues/23926#issuecomment-320370183
  #boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.configurationLimit = 1;

  # smaller font than unicode to shave off a few MB on the boot partition
  boot.loader.grub.font = "${pkgs.grub2}/share/grub/ascii.pf2";
  # stores efi stuff in the EFI partition only, rather than all of /boot,
  # so that there is room for kernels
  #
  # see https://github.com/NixOS/nixpkgs/issues/23926#issuecomment-320370183
#  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  fileSystems."/boot" = {
#  fileSystems."/boot/efi" = {
    device = "/dev/sda15";
    fsType = "vfat";
  };
  ## Nomad
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = false;
  };
  networking = {
    # no IPv6 on OCI
    enableIPv6 = lib.mkForce false; # oci nodes do not have IPv6
  };

  services.nomad.settings = {
    datacenter = "frankfurt-oci";
    client = {
      node_class = "control-plane";
      node_pool = "control-plane";
      cpu_total_compute = 2 * 2000;
    };

    server = {
      enabled = true;
      server_join = {
        retry_join = [
          "inst-ad2ir-control"
          "inst-hqswv-control"
          "inst-kzsrv-control"
        ];
        retry_max = 0;
        retry_interval = "15s";
      };
    };
  };

  # from https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/configuringntpservice.htm
  networking.timeServers = [ "169.254.169.254" ];

  consulNode.server = true;

  vaultNode.enable = true;

  # to figure out ARM CPU clock speed in Nomad
  environment.systemPackages = with pkgs; [ dmidecode ];

  system.stateVersion = "24.05";
}

