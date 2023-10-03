# returns a module
{ interface, confPath, port }: { ... }: {
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
