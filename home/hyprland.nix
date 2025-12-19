{ pkgs, ... }:
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

    if [ "$ACTION" == "do" ]; then
        echo "Applying Stream Resolution: ''${WIDTH}x''${HEIGHT}@''${FPS}"
        
        # 1. Create Headless Output (if not exists)
        # We assume HEADLESS-1 for simplicity. This virtual output acts as the
        # primary display for the stream, matching the client's resolution exactly.
        # Check if it exists?
        if $HYPRCTL monitors | grep "HEADLESS-1"; then
            echo "HEADLESS-1 already exists."
        else
            echo "Creating HEADLESS-1..."
            $HYPRCTL output create headless
        fi

        # 2. Configure Headless to Client Resolution
        echo "Setting HEADLESS-1 to ''${WIDTH}x''${HEIGHT}@''${FPS}..."
        $HYPRCTL keyword monitor "HEADLESS-1, ''${WIDTH}x''${HEIGHT}@''${FPS}, auto, 1"
        
        # 3. Disable Virtual-1 (Physical/QEMU) to force apps to Headless
        echo "Disabling Virtual-1..."
        $HYPRCTL keyword monitor "Virtual-1, disable"
        
    elif [ "$ACTION" == "undo" ]; then
        echo "Reverting to Default..."
        
        # 1. Re-enable Virtual-1
        echo "Enabling Virtual-1..."
        $HYPRCTL keyword monitor "Virtual-1, preferred, auto, 1"
        
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
      # --- Display ---
      # Default to 4K on boot
      monitor = ",3840x2160@60,auto,1";

      # --- General ---
      "$mainMod" = "SUPER";
      "$terminal" = "kitty";

      # --- Input ---
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = false;
        };
      };

      # --- Keybindings ---
      bind = [
        # System
        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, dolphin" # File manager placeholder
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, wofi --show drun"

        # Manual Resolution Switching (Backup)
        "$mainMod, F1, exec, ${sunshine-switch-res}/bin/sunshine-switch-res" # Will reset to default if run manually
        "$mainMod, F2, exec, hyprctl keyword monitor ',1920x1080@60,auto,1'"

        # Focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
      ];
      
      # --- Look & Feel ---
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
      };
    };
  };
}
