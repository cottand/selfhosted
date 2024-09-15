{ config, ... }: {

  services.tailscale = {
    enable = true;
    interfaceName = "ts0";
    port = 46461;
    authKeyFile = config.deployment.keys."tailscale_authkey.txt".path;
    openFirewall = true;
  };

  deployment.keys."tailscale_authkey.txt" = {
    keyCommand = [ "bws-get" "2410a192-c6d5-40ab-96ca-b1ea011bf4a9" ];
    destDir = "/opt/tailscaile";
    user = "root";
  };

  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

  systemd.services.tailscale.after = [ "wg-quick-wg-mesh.service" ];
}
