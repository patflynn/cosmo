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
        "HEADLESS-1, 3840x2160@60, 0x0, 1"
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
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
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
          color = "rgba(1a1a1aee)";
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
      ];

      # --- Startup ---
      exec-once = [
        # Sunshine is handled by systemd at the system level,
        # but you can add user-level apps here.
      ];
    };
  };
}
