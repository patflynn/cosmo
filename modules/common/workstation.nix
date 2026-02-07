{ config, pkgs, ... }:

{
  # --- Desktop Environment ---
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # Required for Steam/X11 apps
  };

  # Enable the Display Manager (SDDM) generically
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "hyprland";

  # Hint Electron apps to use Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
  };

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # --- Remote Access (Sunshine) ---
  # Only enable this if you intend to stream from this machine
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = false; # Restricted to Tailscale below
    applications = {
      env = {
        PATH = "$(PATH):${
          pkgs.lib.makeBinPath [
            pkgs.hyprlock
            pkgs.hyprland
          ]
        }";
      };
      apps = [
        {
          name = "Desktop";
          image-path = "desktop.png";
          prep-cmd = [
            {
              do = "${pkgs.coreutils}/bin/true";
              undo = "${pkgs.hyprland}/bin/hyprctl dispatch exec hyprlock";
            }
          ];
        }
        {
          name = "Steam Big Picture";
          detach-cmd = "${pkgs.util-linux}/bin/runuser -l patrick -c 'steam -shutdown'";
          image-path = "steam.png";
          prep-cmd = [
            {
              do = "${pkgs.util-linux}/bin/runuser -l patrick -c 'steam -bigpicture'";
              undo = "${pkgs.util-linux}/bin/runuser -l patrick -c 'steam -shutdown'";
            }
          ];
        }
      ];
    };
  };

  # Secure Sunshine: Only allow traffic over the Tailscale interface
  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      47984
      47989
      47990
      48010
    ];
    allowedUDPPorts = [
      47998
      47999
      48000
      48002
      48010
    ];
  };

  # Allow Tailscale to handle direct LAN paths correctly while keeping the local firewall tight.
  networking.firewall.checkReversePath = "loose";

  systemd.user.services.sunshine = {
    after = [ "hyprland-session.target" ];
    wants = [ "hyprland-session.target" ];
    environment = {
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/${toString config.users.users.patrick.uid}";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    };
  };
}
