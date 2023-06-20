{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "miki";
  networking.domain = "";
  services.openssh.enable = true;

  users.users.cottand = {
    isNormalUser = true;
    description = "nico";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ ];
    shell = pkgs.zsh;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPJ7FM2wEuWoUuxRkWnP6PNEtG+HOcwcZIt6Qg/Y1jhk nico.dc@outlook.com''
  ];

  networking.firewall.enable = true;
  # networking.firewall.package = pkgs.iptables;
  networking.firewall = {
    allowedUDPPorts = [ 51820 4647 4648 ];
    allowedTCPPorts = [ 22 ];
  };

  environment.systemPackages = [ pkgs.wireguard-tools ];

  virtualisation.docker.enable = true;

  virtualisation.oci-containers.containers = {
    wg-easy = {
      image = "weejewel/wg-easy";
      autoStart = true;
      environment = {
        WG_HOST = "185.216.203.147";
        # PASSWORD = "1234";
        WG_PERSISTENT_KEEPALIVE = "25";
        WG_DEFAULT_ADDRESS = "10.8.0.x";
      };

      # ports = [ "51820:51820/udp" "51821:51821/tcp" ];
      volumes = [ "/root/secret/wg-easy:/etc/wireguard" ];
      extraOptions = [
        "--privileged"
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=SYS_MODULE"
        # "--sysctl='net.ipv4.conf.all.src_valid_mark=1'"
        # "--sysctl='net.ipv4.ip_forward=1'"
      ];
    };
  };


  system.stateVersion = "22.11";
}
