{
  config,
  pkgs,
  ...
}:

let
  # A script to adapt Hyprland to the Moonlight client's resolution
  sunshine-switch-res = pkgs.writeShellScriptBin "sunshine-switch-res" ''
    # Enable logging
    exec > /tmp/sunshine-switch-res.log 2>&1
    echo "--- Sunshine Resolution Switcher ($1) started at $(date) ---"

    ACTION=$1

    # Defaults
    WIDTH=''${SUNSHINE_CLIENT_WIDTH:-3840}
    HEIGHT=''${SUNSHINE_CLIENT_HEIGHT:-2160}
    FPS=''${SUNSHINE_CLIENT_FPS:-60}

    # Ensure HYPRLAND_INSTANCE_SIGNATURE is set
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        export XDG_RUNTIME_DIR="$RUNTIME_DIR"
        if [ -d "$RUNTIME_DIR/hypr" ]; then
             INSTANCE=$(ls -td "$RUNTIME_DIR/hypr"/*/ | head -n 1)
        elif [ -d "/tmp/hypr" ]; then
             INSTANCE=$(ls -td /tmp/hypr/*/ | head -n 1)
        fi
        if [ -n "$INSTANCE" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE=$(basename "$INSTANCE")
        else
            echo "Error: Could not find Hyprland instance signature."
            exit 1
        fi
    fi

    HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
    JQ="${pkgs.jq}/bin/jq"

    if [ "$ACTION" == "do" ]; then
        echo "Applying Stream Resolution: ''${WIDTH}x''${HEIGHT}@''${FPS}"
        
        # 1. Create Headless Output (if not exists)
        if $HYPRCTL monitors | grep "HEADLESS-1"; then
            echo "HEADLESS-1 already exists."
        else
            echo "Creating HEADLESS-1..."
            $HYPRCTL output create headless
        fi

        # 2. Configure Headless to Client Resolution
        echo "Setting HEADLESS-1 to ''${WIDTH}x''${HEIGHT}@''${FPS}..."
        $HYPRCTL keyword monitor "HEADLESS-1, ''${WIDTH}x''${HEIGHT}@''${FPS}, auto, 1"
        
        # 3. Disable Physical Monitor to force apps to Headless
        # Find current physical monitor (not HEADLESS)
        CURRENT_MONITOR=$($HYPRCTL monitors -j | $JQ -r '.[] | select(.name | startswith("HEADLESS") | not) | .name' | head -n 1)
        
        if [ -n "$CURRENT_MONITOR" ]; then
             echo "Detected physical monitor: $CURRENT_MONITOR"
             echo "$CURRENT_MONITOR" > /tmp/sunshine-monitor-backup
             
             echo "Disabling $CURRENT_MONITOR..."
             $HYPRCTL keyword monitor "$CURRENT_MONITOR, disable"
        else
             echo "No physical monitor detected or only HEADLESS active."
        fi
        
    elif [ "$ACTION" == "undo" ]; then
        echo "Reverting to Default..."
        
        # 1. Re-enable Physical Monitor
        if [ -f /tmp/sunshine-monitor-backup ]; then
             OLD_MONITOR=$(cat /tmp/sunshine-monitor-backup)
             echo "Re-enabling $OLD_MONITOR..."
             $HYPRCTL keyword monitor "$OLD_MONITOR, preferred, auto, 1"
             rm /tmp/sunshine-monitor-backup
        else
             echo "No backup found, enabling all/default..."
             $HYPRCTL keyword monitor ", preferred, auto, 1"
        fi
        
        # 2. Remove Headless
        echo "Removing HEADLESS-1..."
        $HYPRCTL output remove HEADLESS-1
        
    else
        echo "Unknown action: $ACTION"
        exit 1
    fi

    echo "Done."
    $HYPRCTL monitors
  '';
in
{
  # The new hotness
  home.packages = with pkgs; [
    kitty
    sunshine-switch-res
  ];

  # Declarative Sunshine Configuration
  xdg.configFile."sunshine/apps.json" = {
    text = builtins.toJSON {
      env = {
        PATH = "$(PATH)";
      };
      apps = [
        {
          name = "Hyprland Desktop";
          image-path = "desktop.png";
          prep-cmd = [
            {
              # Run the script to switch resolution when connecting
              do = "${sunshine-switch-res}/bin/sunshine-switch-res do";
              # Run the script again (which defaults to 4K if no vars) when disconnecting
              undo = "${sunshine-switch-res}/bin/sunshine-switch-res undo";
            }
          ];
          exclude-global-env = false;
          auto-detach = "true";
        }
      ];
    };
    force = true; # Overwrite existing file
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Monitors ---
      # Default to 4K on boot
      monitor = ",3840x2160@60,auto,1";

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

        # Manual Resolution Switching (Backup)
        "$mainMod, F1, exec, ${sunshine-switch-res}/bin/sunshine-switch-res"
        "$mainMod, F2, exec, hyprctl keyword monitor ',1920x1080@60,auto,1'"

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
