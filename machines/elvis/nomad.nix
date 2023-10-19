{ name, ... }: {
  nomadNode = {
    enable = true;
    enableSeaweedFsVolume = true;
    extraSettingsText = ''
      client {
        meta {
          box = "${name}"
          name = "${name}"
        }
      }
    '';
  };
}
