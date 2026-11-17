{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers = [
      "8.8.8.8"
    ];
    defaultGateway = {
      address = "172.31.1.1";
      interface = "eth0";
    };
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce false;
    interfaces = {
      eth0 = {
        ipv4.addresses = [
          { address = "100.64.241.147"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "2a01:4f8:1c19:c1ea::1"; prefixLength = 64; }
          { address = "fe80::9000:aff:fe71:6ffe"; prefixLength = 64; }
        ];
        ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
        ipv6.routes = [{ address = "fe80::1"; prefixLength = 128; }];
      };
      enp7s0 = {
        ipv4.addresses = [
          { address = "10.0.1.4"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "fe80::8400:ff:fe14:3b9"; prefixLength = 64; }
        ];
        ipv4.routes = [
          { address = "10.0.0.1"; prefixLength = 32; }
          { address = "10.0.0.0"; prefixLength = 16; via = "10.0.0.1"; }
        ];
      };
    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="92:00:0a:71:6f:fe", NAME="eth0"
    ATTR{address}=="86:00:00:14:03:b9", NAME="enp7s0"
  '';
}
