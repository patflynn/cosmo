{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;

    settings = {
#      font.size = 18;
      window = {
        title = "Terminal";

        padding = { y = 5; };
        dimensions = {
          lines = 75;
          columns = 100;
        };
      };

      window.opacity = 0.3;

      shell = { program = "${pkgs.zsh}/bin/zsh"; };
    };
  };
}
