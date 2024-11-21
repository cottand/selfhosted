{ config, ... }: {

  services.tailscale = {
    enable = true;
    interfaceName = "ts0";
    port = 46461;
    authKeyFile = config.deployment.keys."tailscale_authkey.txt".path;
    openFirewall = true;
    # see
    # - https://discourse.nixos.org/t/tailscale-ssh-destroys-nix-copy/38781
    # - https://github.com/tailscale/tailscale/issues/14167
    # extraUpFlags = [ "--ssh" ];
  };

  deployment.keys."tailscale_authkey.txt" = {
    keyCommand = [ "bws-get" "2410a192-c6d5-40ab-96ca-b1ea011bf4a9" ];
    destDir = "/opt/tailscaile";
    user = "root";
  };

  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
}
