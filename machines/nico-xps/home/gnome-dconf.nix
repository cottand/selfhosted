{ pkgs, ...}: {
  dconf.settings = if !pkgs.stdenv.isLinux then {} else {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>t";
      command = "guake-toggle";
      name = "nixos-guake";
    };
    "org/gnome/desktop/wm/keybindings" = {
      move-to-workspace-left = [ "<Shift><Super>a" ];
      move-to-workspace-right = [ "<Shift><Super>d" ];
      switch-to-workspace-left = [ "<Super>a" ];
      switch-to-workspace-right = [ "<Super>d" ];
    };
    "org/gnome/shell/extensions/vitals" = {
      alphabetize = true;
      fixed-widths = true;
      hot-sensors = [ "_memory_usage_" "_processor_usage_" "__temperature_avg__" ];
      memory-measurement = 1;
      position-in-panel = 0;
      update-time = 10;
    };
  };
}