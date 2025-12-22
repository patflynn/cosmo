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
    openFirewall = true;
  };

  systemd.user.services.sunshine = {
    environment = {
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/1000";
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    };
  };
}
