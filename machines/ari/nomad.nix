{ pkgs, ... }: {
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      datacenter = "london-home"
      client {
        meta {
          box = "ari"
          name = "ari"
        }
      }
    '';
  };

  services.nomad.extraSettingsPlugins = [ ./plugins ];
  services.nomad.extraPackages = [ pkgs.libusb1 ];
  services.nomad.settings = {
    # must match binary name
    plugin."nomad-usb-device-plugin-linux-amd64-0.4.0" = {
      enabled = true;
      included_vendor_ids = [ ];
      excluded_vendor_ids = [ ];

      included_product_ids = [ ];
      excluded_product_ids = [ ];
    };
  };
  programs.nix-ld = {
    enable = true;
    libraries = [ pkgs.libusb1 ];
  };
}
