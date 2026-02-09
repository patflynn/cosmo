{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.remoting;
in
{
  options.modules.remoting = {
    enable = lib.mkEnableOption "Remote desktop streaming via Sunshine/Moonlight";
  };

  config = lib.mkIf cfg.enable {
    # --- Remote Access (Sunshine) ---
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
            detach-cmd = "${pkgs.util-linux}/bin/runuser -l ${config.cosmo.user.default} -c 'steam -shutdown'";
            image-path = "steam.png";
            prep-cmd = [
              {
                do = "${pkgs.util-linux}/bin/runuser -l ${config.cosmo.user.default} -c 'steam -bigpicture'";
                undo = "${pkgs.util-linux}/bin/runuser -l ${config.cosmo.user.default} -c 'steam -shutdown'";
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
        XDG_RUNTIME_DIR = "/run/user/1000"; # FIXME: Assumes default user UID is 1000
        LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      };
    };
  };
}
