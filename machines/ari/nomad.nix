{
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
}