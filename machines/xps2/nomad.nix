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
}
