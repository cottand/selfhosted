{ pkgs, lib, ... }: {

  programs.git = {
    enable = true;
    userName = "Cottand";
    userEmail = "nico.dc@outlook.com";
    aliases = {
      ac = "!git add . && git commit -m";
      co = "checkout";
      s = "status";
      ps = "push";
      pl = "pull";
      yolo = "commit --ammend -a --no-edit";
    };
  };


  dconf.settings = {

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings=["/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>t";
      command = "guake-toggle";
      name = "nixos-guake";
    };
    "org/gnome/desktop/wm/keybindings" = {
      move-to-workspace-left = ["<Shift><Super>a"];
      move-to-workspace-right=["<Shift><Super>d"];
      switch-to-workspace-left=["<Super>a"];
      switch-to-workspace-right=["<Super>d"];
    };
  };

  home.stateVersion = "22.11";
}
