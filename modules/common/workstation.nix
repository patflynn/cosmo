{ config, pkgs, ... }:

{
  # --- Desktop Environment ---
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # Required for Steam/X11 apps
  };

  # Hint Electron apps to use Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

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
    openFirewall = true;
  };
}
