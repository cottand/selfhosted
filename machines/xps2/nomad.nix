{ name, ... }: {
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    hostVolumes."minecraft-data" = {
      hostPath = "/minecraft-data.d";
      readOnly = false;
    };
    extraSettingsText = ''
      datacenter = "london-home"
      client {
        meta {
          box = "${name}"
          name = "${name}"
        }
      }
    '';
  };
  services.nomad.settings = {
    client.host_network."home_lan".cidr = "192.168.50.0/24";
  };
}
