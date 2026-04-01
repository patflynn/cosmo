{
  config,
  lib,
  pkgs,
  ...
}:

{
  # --- Desktop Environment ---
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # Required for Steam/X11 apps
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  # Enable the Display Manager (SDDM) generically
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "hyprland";

  # --- 1Password ---
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ config.cosmo.user.default ];
  };

  # Session variables for Wayland compatibility
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1"; # For JetBrains IDE compatibility on Wayland
    XDG_SESSION_TYPE = "wayland";
  }
  // lib.optionalAttrs (builtins.elem "nvidia" (config.services.xserver.videoDrivers or [ ])) {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LD_LIBRARY_PATH = lib.mkForce (
      let
        openGLPath = "/run/opengl-driver/lib";
        pipewireJackPath = lib.makeLibraryPath [ pkgs.pipewire.jack ];
      in
      if config.services.pipewire.jack.enable then "${pipewireJackPath}:${openGLPath}" else openGLPath
    );
  };
}
