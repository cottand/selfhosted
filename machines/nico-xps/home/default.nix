{ pkgs, ... }: {

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
  home.stateVersion = "22.11";
}
