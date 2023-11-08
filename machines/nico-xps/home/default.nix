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

    home.file.".ideavimrc" = {
      text = ''
" Show a few lines of context around the cursor. Note that this makes the
" text scroll if you mouse-click near the start or end of the window.
set scrolloff=5

" Do incremental searching.
set incsearch

" Don't use Ex mode, use Q for formatting.
map Q gq



"" -- Map IDE actions to IdeaVim -- https://jb.gg/abva4t
map gf <Action>(ReformatCode)

map gr <Action>(Run)
"" Map \b to toggle the breakpoint on the current line
"map \b <Action>(ToggleLineBreakpoint)


" Find more examples here: https://jb.gg/share-ideavimrc
      '';
    };

  home.stateVersion = "22.11";
}
