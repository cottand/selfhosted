let
  interface = "wg-ci";
  confPath = ../../secret/wg-ci/wg-ci.conf;
  port = 55726;
in
{ config, pkgs, name, ... }: {
  # see https://colmena.cli.rs/unstable/features/keys.html
  deployment.keys."${interface}.conf" = {
    text = (builtins.readFile confPath);

    destDir = "/etc/wireguard";

    uploadAt = "pre-activation";
  };
  networking = {
    wg-quick.interfaces.${interface}.configFile = "/etc/wireguard/${interface}.conf";
    firewall.trustedInterfaces = [ interface ];
    firewall.allowedUDPPorts = [ port ];
  };

  systemd.services."wg-quick-${interface}".partOf = [ "${interface}.conf-key.service" ];
}
