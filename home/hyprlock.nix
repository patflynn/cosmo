{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          color = "rgba(30, 30, 46, 1.0)"; # Catppuccin Mocha Base
          blur_passes = 3; # 0 disables blurring
          blur_size = 7;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "250, 50";
          outline_thickness = 3;
          dots_size = 0.33; # Scale of input-field height, 0.2 - 0.8
          dots_spacing = 0.15; # Scale of dots' absolute size, 0.0 - 1.0
          dots_center = true;
          dots_rounding = -1; # -1 default circle, -2 follow input-field rounding
          outer_color = "rgb(24, 24, 37)"; # Catppuccin Mocha Mantle
          inner_color = "rgb(30, 30, 46)"; # Catppuccin Mocha Base
          font_color = "rgb(205, 214, 244)"; # Catppuccin Mocha Text
          fade_on_empty = true;
          fade_timeout = 1000; # Milliseconds before fade_on_empty is triggered.
          placeholder_text = "<i>Input Password...</i>"; # Text rendered in the input box when it's empty.
          hide_input = false;
          rounding = -1; # -1 default circle, -2 follow input-field rounding
          check_color = "rgb(249, 226, 175)"; # Catppuccin Mocha Yellow
          fail_color = "rgb(243, 139, 168)"; # Catppuccin Mocha Red
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>"; # can be set to empty
          fail_transition = 300; # transition time in ms between normal outer_color and fail_color
          capslock_color = -1;
          numlock_color = -1;
          bothlock_color = -1; # when both locks are active. -1 means don't change outer color (same for above)
          invert_numlock = false; # change color if numlock is off
          swap_font_color = false; # see below

          position = "0, -20";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        # TIME
        {
          monitor = "";
          text = "cmd[update:1000] echo \"$(date +\"%H:%M\")\"";
          color = "rgb(205, 214, 244)"; # Catppuccin Mocha Text
          font_size = 120;
          font_family = "JetBrains Mono ExtraBold";
          position = "0, -300";
          halign = "center";
          valign = "top";
        }
        # DATE
        {
          monitor = "";
          text = "cmd[update:1000] echo \"$(date +\"%A, %d %B %Y\")\"";
          color = "rgb(205, 214, 244)"; # Catppuccin Mocha Text
          font_size = 30;
          font_family = "JetBrains Mono";
          position = "0, -200";
          halign = "center";
          valign = "top";
        }
      ];
    };
  };
}
