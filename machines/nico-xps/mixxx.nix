{ pkgs, lib, ... }: {
  users.users.cottand.packages = [
    pkgs.mixxx
  ];

  nixpkgs.config.qt5.enable = true;

  environment.systemPackages = with pkgs; [
    # The following is a Qt theme engine, which can be configured with kvantummanager
    libsForQt5.qtstyleplugin-kvantum
  ];

  environment.variables = {
    # This will become a global environment variable
    "QT_STYLE_OVERRIDE" = "kvantum";
  };

}
