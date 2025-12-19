{ pkgs, ... }:
let
  # A script to adapt Hyprland to the Moonlight client's resolution
  sunshine-switch-res = pkgs.writeShellScriptBin "sunshine-switch-res" ''
    # If variables are missing, default to 4K (3840x2160@60)
    # SUNSHINE_CLIENT_WIDTH/HEIGHT are provided by Sunshine when a client connects
    WIDTH=''${SUNSHINE_CLIENT_WIDTH:-3840}
    HEIGHT=''${SUNSHINE_CLIENT_HEIGHT:-2160}
    FPS=''${SUNSHINE_CLIENT_FPS:-60}

    # Tell Hyprland to change resolution
    ${pkgs.hyprland}/bin/hyprctl keyword monitor ", ''${WIDTH}x''${HEIGHT}@''${FPS},auto,1"
  '';
in
{
  # The new hotness
  home.packages = with pkgs; [ 
    ghostty 
    sunshine-switch-res
  ];

  # Declarative Sunshine Configuration
  xdg.configFile."sunshine/apps.json".text = builtins.toJSON {
    env = {
      PATH = "$(PATH)";
    };
    apps = [
      {
        name = "Desktop";
        image-path = "desktop.png";
        prep-cmd = [
          {
            # Run the script to switch resolution when connecting
            do = "${sunshine-switch-res}/bin/sunshine-switch-res";
            # Run the script again (which defaults to 4K if no vars) when disconnecting
            undo = "${sunshine-switch-res}/bin/sunshine-switch-res";
          }
        ];
        exclude-global-env = false;
        auto-detach = "true";
      }
    ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Display ---
      # Default to 4K on boot
      monitor = ",3840x2160@60,auto,1";

      # --- General ---
      "$mainMod" = "SUPER";
      "$terminal" = "ghostty";

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
