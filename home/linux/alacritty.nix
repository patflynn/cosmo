# Alacritty configuration for home-manager
{ config, lib, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "xterm-256color";
      };
      
      window = {
        padding = {
          x = 5;
          y = 5;
        };
        decorations = "full";
        startup_mode = "Windowed";
        dynamic_title = true;
      };
      
      font = {
        normal = {
          family = "Monospace";
          style = "Regular";
        };
        bold = {
          family = "Monospace";
          style = "Bold";
        };
        italic = {
          family = "Monospace";
          style = "Italic";
        };
        size = 12.0;
      };
      
      colors = {
        primary = {
          background = "0x1a1b26";
          foreground = "0xa9b1d6";
        };
        normal = {
          black = "0x32344a";
          red = "0xf7768e";
          green = "0x9ece6a";
          yellow = "0xe0af68";
          blue = "0x7aa2f7";
          magenta = "0xad8ee6";
          cyan = "0x449dab";
          white = "0x787c99";
        };
        bright = {
          black = "0x444b6a";
          red = "0xff7a93";
          green = "0xb9f27c";
          yellow = "0xff9e64";
          blue = "0x7da6ff";
          magenta = "0xbb9af7";
          cyan = "0x0db9d7";
          white = "0xacb0d0";
        };
      };
    };
  };
}