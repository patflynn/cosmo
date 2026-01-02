{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hyprlock.nix
  ];

  home.packages = with pkgs; [
    grim # Screenshot tool
    slurp # Region selector
    swappy # Snapshot editor
    wl-clipboard # Clipboard manager
    wf-recorder # Screen recorder
    ffmpeg # For GIF conversion
    libnotify # For notifications

    # Script to record GIF
    (pkgs.writeShellScriptBin "record-gif" ''
      #!/usr/bin/env bash

      # Define output
      DATE=$(date +%Y-%m-%d_%H-%M-%S)
      DIR="$HOME/Pictures/GIFs"
      MKV="$DIR/recording_$DATE.mkv"
      GIF="$DIR/recording_$DATE.gif"

      mkdir -p "$DIR"

      # Notify and Select Region
      notify-send "GIF Recording" "Select region to start recording..."

      if ! REGION=$(slurp); then
          notify-send "GIF Recording" "Cancelled"
          exit 1
      fi

      notify-send "GIF Recording" "Recording started! Press Super+Shift+S to stop."

      # Record to MKV (more robust than MP4 for interruption)
      wf-recorder -g "$REGION" -f "$MKV"

      # Convert to GIF after recording stops
      notify-send "GIF Recording" "Converting to GIF..."

            # Generate palette for better quality
            palette="/tmp/palette.png"
            filters="fps=15,scale=320:-1:flags=lanczos"
            
            ffmpeg -v warning -i "$MKV" -vf "$filters,palettegen" -y "$palette"
            ffmpeg -v warning -i "$MKV" -i "$palette" -lavfi "$filters [x]; [x][1:v] paletteuse" -y "$GIF"
            
            rm "$palette"
            rm "$MKV"
            
            notify-send "GIF Recording" "Saved to $GIF"
            wl-copy "$GIF"    '')
  ];

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
        "DP-1, disable"
        "DP-2, disable"
        "DP-3, disable"
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

      exec-once = [
        "hyprlock"
      ];

      # --- Keybindings ---
      "$mainMod" = "SUPER";
      bind = [
        "$mainMod, Q, exec, kitty"
        "$mainMod, C, killactive,"
        "$mainMod, M, exec, hyprlock" # Lock screen (safeguard against accidental exit)
        "$mainMod, E, exec, dolphin"
        "$mainMod, B, exec, google-chrome-stable"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, wofi --show drun"
        "$mainMod, P, pseudo," # pseudotile
        "$mainMod, L, exec, hyprlock" # Lock screen

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

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy" # Region to clipboard
        "$mainMod, Print, exec, grim -g \"$(slurp)\" - | swappy -f -" # Region to Swappy
        "SHIFT, Print, exec, grim - | wl-copy" # Full screen to clipboard

        # Screenshot Alternatives (No Print Key)
        "$mainMod SHIFT, P, exec, grim -g \"$(slurp)\" - | wl-copy" # Region to clipboard
        "$mainMod ALT, P, exec, grim -g \"$(slurp)\" - | swappy -f -" # Region to Swappy
        "$mainMod CTRL, P, exec, grim - | wl-copy" # Full screen to clipboard

        # Screen Recording
        "$mainMod SHIFT, G, exec, record-gif" # Record GIF (Region)
        "$mainMod SHIFT, S, exec, pkill --signal SIGINT wf-recorder" # Stop Recording
      ];

      debug = {
        disable_logs = false;
      };
    };
  };

  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = lib.mkForce "Hyprland session";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.hyprland-autostart = {
    Unit = {
      Description = "Hyprland Autostart (Monitor & Session Target)";
      After = [ "dbus.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c '/etc/profiles/per-user/patrick/bin/sunshine-resolution 3840 2160 60 && systemctl --user start hyprland-session.target'";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
