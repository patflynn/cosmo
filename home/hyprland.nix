{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
    ./hyprpaper.nix
    ./mako.nix
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

    # Screenshot scripts (avoids quoting issues in Hyprland binds)
    (pkgs.writeShellScriptBin "screenshot-region" ''
      REGION=$(slurp) || exit 0
      grim -g "$REGION" - | wl-copy
    '')
    (pkgs.writeShellScriptBin "screenshot-region-edit" ''
      REGION=$(slurp) || exit 0
      grim -g "$REGION" - | swappy -f -
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
      ' | fuzzel --dmenu --width 80 --lines 20 --prompt "Keybindings: "
    '')
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Monitors ---
      # Auto-detect monitors with preferred resolution
      # Format: name, resolution, position, scale
      monitor = [
        "desc:Dell Inc. DELL U4025QW 37P0B84, highrr, auto, 1"
        ", preferred, auto, 1"
      ];

      # --- Workspace Layouts ---
      workspace = [
        "1, layout:scrolling"
        "2, layout:master"
        "3, layout:master"
        "4, layout:master"
        "5, layout:dwindle"
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
        layout = "master";
      };

      # --- Master Layout ---
      master = {
        new_status = "slave";
        orientation = "left";
        mfact = 0.55;
      };

      # --- Scrolling Layout ---
      scrolling = {
        column_width = "0.3";
        explicit_column_widths = "0.25, 0.3, 0.4, 0.5, 0.667, 1.0";
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
        "blur on, ignore_alpha 1, match:namespace waybar"
        "blur on, ignore_alpha 1, match:namespace notifications"
      ];

      # --- Window Rules ---
      # Hide Chrome's Spotify "now playing" floating popup (redundant with waybar mpris)
      windowrule = [
        "match:class ^(google-chrome)$, match:float yes, match:title .*•.*, workspace special:trash silent"
        "match:float yes, match:title .*is sharing your screen.*, workspace special:trash silent"
      ];

      # --- Keybindings ---
      # NOTE: Keyboard is a Kinesis Advantage (split ergo). Super, Enter, Space,
      # Ctrl(R), PgUp, PgDn are all on the right thumb cluster. Avoid chords
      # combining any two of these keys (e.g. Super+Return, Super+Space).
      # Super+Backspace works (Backspace is on the left thumb cluster).
      #
      # Directional home row keys: J=left, K=down, L=up, ;=right
      # (Kinesis Advantage key wells make JKL; more natural than HJKL)
      #
      # Modifier scheme for JKL;:
      #   Super       = focus (spatial, works across all layouts)
      #   Super+Shift = move/swap window
      #   Super+Ctrl  = resize
      #   Super+Alt   = group/tab cycling
      "$mainMod" = "SUPER";
      bindd = [
        "$mainMod, Q, Open terminal, exec, kitty"
        "$mainMod, C, Close window, killactive,"
        "$mainMod, M, Lock screen, exec, hyprlock"
        "$mainMod, E, File manager, exec, thunar"
        "$mainMod, Y, Terminal file manager, exec, kitty -e yazi"
        "$mainMod, B, Open browser, exec, google-chrome-stable"
        "$mainMod, Z, Open Zen browser, exec, zen-beta"
        "$mainMod, V, Toggle floating, togglefloating,"
        "$mainMod, F, Toggle fullscreen, fullscreen, 1"
        "$mainMod SHIFT, F, True fullscreen, fullscreen, 0"
        "$mainMod, R, App launcher, exec, fuzzel"
        "$mainMod, slash, Keybindings cheatsheet, exec, hypr-cheatsheet"
        "$mainMod, P, Pseudotile, pseudo,"

        # Focus
        "$mainMod, left, Focus left, movefocus, l"
        "$mainMod, right, Focus right, movefocus, r"
        "$mainMod, up, Focus up, movefocus, u"
        "$mainMod, down, Focus down, movefocus, d"

        # Focus (home row — spatial movefocus works across all layouts)
        "$mainMod, J, Focus left, movefocus, l"
        "$mainMod, K, Focus down, movefocus, d"
        "$mainMod, L, Focus up, movefocus, u"
        "$mainMod, semicolon, Focus right, movefocus, r"

        # Move window
        "$mainMod SHIFT, left, Move window left, movewindow, l"
        "$mainMod SHIFT, right, Move window right, movewindow, r"
        "$mainMod SHIFT, up, Move window up, movewindow, u"
        "$mainMod SHIFT, down, Move window down, movewindow, d"

        # Move window (home row)
        "$mainMod SHIFT, J, Move window left, movewindow, l"
        "$mainMod SHIFT, K, Move window down, movewindow, d"
        "$mainMod SHIFT, L, Move window up, movewindow, u"
        "$mainMod SHIFT, semicolon, Move window right, movewindow, r"

        # Master layout
        "$mainMod, BackSpace, Swap with master, layoutmsg, swapwithmaster master"
        "$mainMod SHIFT, BackSpace, Focus master, layoutmsg, focusmaster auto"
        "$mainMod, comma, Add master window, layoutmsg, addmaster"
        "$mainMod, period, Remove master window, layoutmsg, removemaster"

        # Scroll layout (workspace 1)
        "$mainMod, equal, Fit visible columns, layoutmsg, fit visible"
        "$mainMod SHIFT, equal, Cycle column width, layoutmsg, colresize +conf"

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
        ", Print, Screenshot region to clipboard, exec, screenshot-region"
        "$mainMod, Print, Screenshot region to editor, exec, screenshot-region-edit"
        "SHIFT, Print, Screenshot fullscreen, exec, grim - | wl-copy"

        # Screenshot alternatives (no Print key)
        "$mainMod SHIFT, P, Screenshot region to clipboard, exec, screenshot-region"
        "$mainMod ALT, P, Screenshot region to editor, exec, screenshot-region-edit"
        "$mainMod CTRL, P, Screenshot fullscreen, exec, grim - | wl-copy"

        # Screen recording
        "$mainMod SHIFT, G, Record GIF, exec, record-gif"
        "$mainMod SHIFT, S, Stop recording, exec, pkill --signal SIGINT wf-recorder"

        # Workspace cycling
        "$mainMod, Tab, Next workspace, workspace, m+1"
        "$mainMod SHIFT, Tab, Previous workspace, workspace, m-1"

        # Urgent
        "$mainMod, U, Focus urgent window, focusurgentorlast,"

        # Groups (tabbed windows)
        "$mainMod, G, Toggle group, togglegroup,"
        "$mainMod ALT, J, Change active in group backward, changegroupactive, b"
        "$mainMod ALT, semicolon, Change active in group forward, changegroupactive, f"

        # Notifications
        "$mainMod SHIFT, N, Restore notification, exec, makoctl restore"
        "$mainMod, N, Dismiss notification, exec, makoctl dismiss"
      ];

      # --- Mouse Bindings ---
      bindm = [
        "ALT, mouse:272, movewindow"
        "ALT, mouse:273, resizewindow"
      ];

      # --- Keyboard Resize (Super+Ctrl+JKL;) ---
      binde = [
        "$mainMod CTRL, J, resizeactive, -20 0"
        "$mainMod CTRL, K, resizeactive, 0 20"
        "$mainMod CTRL, L, resizeactive, 0 -20"
        "$mainMod CTRL, semicolon, resizeactive, 20 0"
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
