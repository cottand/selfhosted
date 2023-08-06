{ config, pkgs, ... }:
{
  # Enable WireGuard
  networking.wg-quick.interfaces = {
    # wg0 = {
    #   address = [ "10.8.0.102/24" "10.10.4.1/16" ];
    #   #listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

    #   privateKeyFile = "/root/secret/wg0/private.key";

    #   dns = [ "10.8.0.1" "10.8.0.8" "10.8.0.100" ];

    #   peers = [
    #     {
    #       publicKey = "Nn6nM3ykE5TfYzRgnTCPAsiaVCV9QmKHvbscrPdhcms=";
    #       presharedKeyFile = "/root/secret/wg0/preshared.key";

    #       # Forward all the traffic via VPN:
    #       #   allowedIPs = [ "0.0.0.0/0" ];
    #       # traffic not routed through cosmo:
    #       allowedIPs = [ "10.8.0.0/24" "10.10.0.0/16" ];

    #       endpoint = "vps.dcotta.eu:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

    #       # Send keepalives every 25 seconds. Important to keep NAT tables alive.
    #       persistentKeepalive = 25;
    #     }
    #   ];
    # };
    wg-mesh = {
      address = [ "10.8.0.102/24" "10.10.4.1/16" ];
      #listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      privateKeyFile = "/root/secret/wg0/private.key";

      dns = [ "10.8.0.1" "10.8.0.8" "10.8.0.100" ];

      peers = [
        {
          publicKey = "Nn6nM3ykE5TfYzRgnTCPAsiaVCV9QmKHvbscrPdhcms=";
          presharedKeyFile = "/root/secret/wg0/preshared.key";

          # Forward all the traffic via VPN:
          #   allowedIPs = [ "0.0.0.0/0" ];
          # traffic not routed through cosmo:
          allowedIPs = [ "10.8.0.0/24" "10.10.0.0/16" ];

          endpoint = "vps.dcotta.eu:55820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
