{ config, pkgs, ... }: {
  networking.enableIPv6 = true;

  # Specific to contabo - see https://contabo.com/blog/adding-ipv6-connectivity-to-your-server/
  networking.defaultGateway6 = {
    address = "fe80::1";
    interface = "ens18";
  };
  # IPv6 address given by Contabo personal dashboard
  networking.interfaces.ens18.ipv6.addresses = [{
    address = "2a02:c207:2172:6974::1";
    prefixLength = 64;
  }];
}
