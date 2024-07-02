{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers = [
      "8.8.8.8"
    ];
    defaultGateway = "172.31.1.1";
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce false;
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          { address = "188.245.36.107"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "2a01:4f8:1c1b:91ce::1"; prefixLength = 64; }
          { address = "fe80::9400:3ff:fe6e:bb42"; prefixLength = 64; }
        ];
        ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
        ipv6.routes = [{ address = "fe80::1"; prefixLength = 128; }];
      };
      enp7s0 = {
        ipv4.addresses = [
          { address = "10.0.1.1"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "fe80::8400:ff:fe92:a3"; prefixLength = 64; }
        ];
        ipv4.routes = [
          { address = "10.0.0.1"; prefixLength = 32; }
          { address = "10.0.0.0"; prefixLength = 16; via = "10.0.0.1"; }
        ];
      };
    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="96:00:03:6e:bb:42", NAME="eth0"
    ATTR{address}=="86:00:00:92:00:a3", NAME="enp7s0"
  '';
}
