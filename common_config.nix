{ config, pkgs, ... }:
{

      nixpkgs.config.allowUnfree = true;
      services.openssh.enable = true;
        # Enable zsh
        programs.zsh.enable = true;

        # Enable Oh-my-zsh
        programs.zsh.ohMyZsh = {
          enable = true;
          plugins = [ "git" "sudo" "docker" ];
        };


      # Set your time zone.
      time.timeZone = "Europe/London";

      # Select internationalisation properties.
      i18n.defaultLocale = "en_GB.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_GB.UTF-8";
        LC_IDENTIFICATION = "en_GB.UTF-8";
        LC_MEASUREMENT = "en_GB.UTF-8";
        LC_MONETARY = "en_GB.UTF-8";
        LC_NAME = "en_GB.UTF-8";
        LC_NUMERIC = "en_GB.UTF-8";
        LC_PAPER = "en_GB.UTF-8";
        LC_TELEPHONE = "en_GB.UTF-8";
        LC_TIME = "en_GB.UTF-8";
      };

      # Configure keymap in X11
      services.xserver = {
        layout = "gb";
        xkbVariant = "";
      };

      # Configure console keymap
      console.keyMap = "uk";
}