{ config, pkgs, ... }:
{
  # Enable WireGuard
  networking.wg-quick.interfaces = {
    wg0 = {
      address = [ "10.8.0.101/24" ];
      #listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      privateKeyFile = "/root/secret/wg-private.key";

      dns = [ "10.8.0.1" ];

      peers = [
        {
          publicKey = "Nn6nM3ykE5TfYzRgnTCPAsiaVCV9QmKHvbscrPdhcms=";
          presharedKey = "6/gaPS76xz+TWmxRkCBvNQPmKJD/Y2BAKnnmwlEEGDc=";

          # Forward all the traffic via VPN.
          #              allowedIPs = [ "0.0.0.0/0" ];
          # traffic not routed through cosmo
          allowedIPs = [ "10.8.0.0/24" ];

          endpoint = "vps.dcotta.eu:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
    wg-local = {
      privateKeyFile = "/root/secret/wg-local/secret";
      listenPort = 51820;
      address = [ "10.8.1.101/24" ];

      peers = [
          # ari
        {
          publicKey = "tBWmnEM391TVidhOfkUunfWNDht42nO7LZeLvmeOXSc=";
          allowedIPs = [ "10.8.1.8/32" ];

        }
      ];
    };
  };
}
