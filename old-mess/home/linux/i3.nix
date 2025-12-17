# i3 configuration for home-manager
{ config, lib, pkgs, ... }:

{
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "alacritty";
      menu = "rofi -show drun";

      keybindings = lib.mkOptionDefault {
        "${config.xsession.windowManager.i3.config.modifier}+Return" = "exec ${config.xsession.windowManager.i3.config.terminal}";
        "${config.xsession.windowManager.i3.config.modifier}+d" = "exec ${config.xsession.windowManager.i3.config.menu}";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+q" = "kill";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+c" = "reload";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+r" = "restart";
        "${config.xsession.windowManager.i3.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Exit i3?' -b 'Yes' 'i3-msg exit'";

        # Lock screen
        "${config.xsession.windowManager.i3.config.modifier}+l" = "exec i3lock-color -c 000000";

        # Screenshot
        "Print" = "exec maim -s | xclip -selection clipboard -t image/png";
      };

      bars = [
        {
          position = "bottom";
          statusCommand = "i3status";
          colors = {
            background = "#000000";
            statusline = "#ffffff";
            separator = "#666666";
          };
        }
      ];
    };
  };
}
