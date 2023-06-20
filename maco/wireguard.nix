{ config, pkgs, ... }:
{
  # Enable WireGuard
  networking.wg-quick.interfaces = {
    wg-germany = {
      address = [ "10.8.0.5/24" ];
      #listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      privateKeyFile = "/root/secret/wg-germany/private";

      dns = [ "10.8.0.1" ];

      peers = [
        {
          publicKey = "Nn6nM3ykE5TfYzRgnTCPAsiaVCV9QmKHvbscrPdhcms=";
          presharedKey = "2lF6fzhbDCKOI4gxNrnwCCabosImrCoMCQe2KH+FXH4=";

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
  #   # to elvis
  #   wg-local = {
  #     privateKeyFile = "/root/secret/wg-local/private";

  #     address = [ "10.8.1.5/24" ];
  #     dns = [ "10.8.0.1" ];
  #     #elvis
  #     peers = [{
  #       publicKey = "XjVaA/NmTjm8E0WBLMx/0wHMmGKt/AllSgGowvUMnE0=";
  #       allowedIPs = [ "10.8.1.0/24" ];
  #       endpoint = "elvis.vps6.dcotta.eu:52820";
  #       persistentKeepalive = 25;
  #     }];
  #   };
  };
}
