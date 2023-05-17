{ config, pkgs, ... }:
{
     # Enable WireGuard
      networking.wg-quick.interfaces = {
        wg0 = {
          address = [ "10.8.0.8/24" ];
          #listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

          privateKeyFile = "/root/secret/wg-private.key";

          dns = [ "10.8.0.1" ];

          peers = [
            {
              publicKey = "Nn6nM3ykE5TfYzRgnTCPAsiaVCV9QmKHvbscrPdhcms=";
              presharedKey = "v/X4KYrjVsfqszt8Ae4ivM2OvjXQ2o6D1MjFBv1AbfQ=";

              # Forward all the traffic via VPN.
#              allowedIPs = [ "0.0.0.0/0" ];
              # traffic not routed through cosmo
              allowedIPs = [ "10.8.0.0/24" ];
#              allowedIPs = [ 0.0.0.0/5, 8.0.0.0/7, 10.0.0.0/13, 10.8.0.0/29, 10.8.0.9/32, 10.8.0.10/31, 10.8.0.12/30, 10.8.0.16/28, 10.8.0.32/27, 10.8.0.64/26, 10.8.0.128/25, 10.8.1.0/24, 10.8.2.0/23, 10.8.4.0/22, 10.8.8.0/21, 10.8.16.0/20, 10.8.32.0/19, 10.8.64.0/18, 10.8.128.0/17, 10.9.0.0/16, 10.10.0.0/15, 10.12.0.0/14, 10.16.0.0/12, 10.32.0.0/11, 10.64.0.0/10, 10.128.0.0/9, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/1 ];
              # Or forward only particular subnets
              #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

              endpoint = "vps.dcotta.eu:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

              # Send keepalives every 25 seconds. Important to keep NAT tables alive.
              persistentKeepalive = 25;
            }
          ];
        };
     };
}