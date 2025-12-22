{
  config,
  pkgs,
  ...
}:

{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Monitors ---
      # For headless/streaming, we often want a fixed resolution.
      # Format: name, resolution, position, scale
      monitor = [
        "HDMI-A-1, disable"
        "HDMI-A-2, disable"
        "HDMI-A-3, disable"
        "HDMI-A-4, disable"
        ", preferred, auto, 1"
      ];

      # --- Input ---
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };

      # --- General ---
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgb(cba6f7) rgb(94e2d5) 45deg"; # Catppuccin Mocha Mauve -> Teal
        "col.inactive_border" = "rgb(585b70)"; # Catppuccin Mocha Surface2
        layout = "dwindle";
      };

      # --- Decoration ---
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1e1e2eee)"; # Catppuccin Mocha Base
        };
      };

      # --- Cursor ---
      cursor = {
        no_hardware_cursors = true;
      };

      # --- Keybindings ---
      "$mainMod" = "SUPER";
      bind = [
        "$mainMod, Q, exec, kitty"
        "$mainMod, C, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, dolphin"
        "$mainMod, G, exec, google-chrome-stable"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, wofi --show drun"
        "$mainMod, P, pseudo," # pseudotile

        # Move focus with mainMod + arrow keys
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
      ];

      # --- Startup ---
      exec-once = [
        "/etc/profiles/per-user/patrick/bin/hyprctl output create headless"
        "/etc/profiles/per-user/patrick/bin/sunshine-resolution 3840 2160 60"
        "sleep 5 && systemctl --user start sunshine"
      ];

      debug = {
        disable_logs = false;
      };
    };
  };
}
