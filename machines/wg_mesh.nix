{ config, pkgs, name, ... }: {
  # see https://colmena.cli.rs/unstable/features/keys.html
  deployment.keys."wg-mesh.conf" = {
    # Alternatively, `text` (string) or `keyFile` (path to file)
    # may be specified.
    # keyFile = ../secret/wg-mesh/${name}.conf;
    text = (builtins.readFile ../secret/wg-mesh/${name}.conf);

    destDir = "/etc/wireguard";

    uploadAt = "pre-activation";
  };
  networking = {
    wg-quick.interfaces.wg-mesh.configFile = "/etc/wireguard/wg-mesh.conf";
    firewall.trustedInterfaces = [ "wg-mesh" ];
    firewall.allowedUDPPorts = [ 55820 ];
  };

  # A depends on B
  systemd.services.wg-quick-wg-mesh.partOf = [ "wg-mesh.conf-key.service" ];
}
