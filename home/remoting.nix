{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    jq # JSON processor (used by sunshine-resolution script)

    # Custom script to sync resolution with Sunshine client
    (pkgs.writeShellScriptBin "sunshine-resolution" (
      builtins.readFile ./scripts/sunshine-resolution.sh
    ))
  ];

  # Headless monitor configuration for streaming
  # Disables physical outputs so Sunshine can create a virtual display
  wayland.windowManager.hyprland.settings = {
    monitor = lib.mkBefore [
      "HDMI-A-1, disable"
      "HDMI-A-2, disable"
      "HDMI-A-3, disable"
      "HDMI-A-4, disable"
      "DP-1, disable"
      "DP-2, disable"
      "DP-3, disable"
    ];

    # Lock screen on session start for security
    exec-once = [ "hyprlock" ];
  };

  # Autostart service to configure resolution and start Sunshine
  systemd.user.services.hyprland-autostart = {
    Unit = {
      Description = "Hyprland Autostart (Monitor & Session Target)";
      After = [ "dbus.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c '/etc/profiles/per-user/${config.home.username}/bin/sunshine-resolution 3840 2160 60 && systemctl --user start hyprland-session.target'";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
