{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hyprlock.nix
    ./hyprpaper.nix
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    grim # Screenshot tool
    slurp # Region selector
    swappy # Snapshot editor
    wl-clipboard # Clipboard manager
    wf-recorder # Screen recorder
    ffmpeg # For GIF conversion
    jq # JSON processor
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
      # higher quality scale
      filters="fps=15,scale=720:-1:flags=lanczos"

      ffmpeg -v warning -i "$MKV" -vf "$filters,palettegen" -y "$palette"
      ffmpeg -v warning -i "$MKV" -i "$palette" -lavfi "$filters [x]; [x][1:v] paletteuse" -y "$GIF"

      rm "$palette"
      rm "$MKV"

      notify-send "GIF Recording" "Saved to $GIF"
      wl-copy "$GIF"
    '')

    # Cheatsheet Script
    (pkgs.writeShellScriptBin "hypr-cheatsheet" ''
      #!/usr/bin/env bash
      # Parse keybindings from hyprctl using structured JSON
      hyprctl binds -j | jq -r '
        .[]
        | select(.has_description and .description != "")
        | (
            (if .modmask == 0 then ""
             else [
               (if (.modmask % 128) >= 64 then "Super" else empty end),
               (if (.modmask % 2) >= 1 then "Shift" else empty end),
               (if (.modmask % 8) >= 4 then "Ctrl" else empty end),
               (if (.modmask % 16) >= 8 then "Alt" else empty end)
             ] | join(" + ")
             end)
          ) as $mods
        | (if $mods == "" then .key else $mods + " + " + .key end)
          + " — " + .description
      ' | wofi --dmenu --width 1000 --height 600 -p "Keybindings"
    '')
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Monitors ---
      # Auto-detect monitors with preferred resolution
      # Format: name, resolution, position, scale
      monitor = [
        "DP-2, highrr, auto, 1"
        ", preferred, auto, 1"
      ];

      # --- Input ---
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
        natural_scroll = true;
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

      # --- Layer Rules ---
      layerrule = [
        "blur, waybar"
        "ignorezero, waybar"
      ];

      # --- Keybindings ---
      "$mainMod" = "SUPER";
      bindd = [
        "$mainMod, Q, Open terminal, exec, kitty"
        "$mainMod, C, Close window, killactive,"
        "$mainMod, M, Lock screen, exec, hyprlock"
        "$mainMod, E, File manager, exec, dolphin"
        "$mainMod, Y, Terminal file manager, exec, kitty -e yazi"
        "$mainMod, B, Open browser, exec, google-chrome-stable"
        "$mainMod, V, Toggle floating, togglefloating,"
        "$mainMod, R, App launcher, exec, wofi --show drun"
        "$mainMod, slash, Keybindings cheatsheet, exec, hypr-cheatsheet"
        "$mainMod, P, Pseudotile, pseudo,"
        "$mainMod, L, Lock screen, exec, hyprlock"

        # Focus
        "$mainMod, left, Focus left, movefocus, l"
        "$mainMod, right, Focus right, movefocus, r"
        "$mainMod, up, Focus up, movefocus, u"
        "$mainMod, down, Focus down, movefocus, d"

        # Workspaces
        "$mainMod, 1, Workspace 1, workspace, 1"
        "$mainMod, 2, Workspace 2, workspace, 2"
        "$mainMod, 3, Workspace 3, workspace, 3"
        "$mainMod, 4, Workspace 4, workspace, 4"
        "$mainMod, 5, Workspace 5, workspace, 5"

        # Move to workspace
        "$mainMod SHIFT, 1, Move to workspace 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, Move to workspace 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, Move to workspace 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, Move to workspace 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, Move to workspace 5, movetoworkspace, 5"

        # Screenshots
        ", Print, Screenshot region to clipboard, exec, grim -g \"$(slurp)\" - | wl-copy"
        "$mainMod, Print, Screenshot region to editor, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "SHIFT, Print, Screenshot fullscreen, exec, grim - | wl-copy"

        # Screenshot alternatives (no Print key)
        "$mainMod SHIFT, P, Screenshot region to clipboard, exec, grim -g \"$(slurp)\" - | wl-copy"
        "$mainMod ALT, P, Screenshot region to editor, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mainMod CTRL, P, Screenshot fullscreen, exec, grim - | wl-copy"

        # Screen recording
        "$mainMod SHIFT, G, Record GIF, exec, record-gif"
        "$mainMod SHIFT, S, Stop recording, exec, pkill --signal SIGINT wf-recorder"
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
}
