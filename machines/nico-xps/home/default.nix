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
    };
  };
  home.stateVersion = "22.11";
}
