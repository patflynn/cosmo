{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        no_fade_in = true;
        grace = 0;
        disable_loading_bar = true;
      };

      background = [
        {
          monitor = "";
          path = ""; # Empty for solid color
          color = "rgba(25, 20, 20, 1.0)";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "200, 50";
          position = "0, -20";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          placeholder_text = "Password...";
          shadow_passes = 2;
        }
      ];
    };
  };
}
