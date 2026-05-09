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

  # --- xdg portal restart policy ---
  # 2026-05-05 incident on classic-laddie: dbus-broker hit its per-UID byte
  # quota for UID 1000 and force-disconnected several user-session D-Bus
  # consumers. xdg-desktop-portal and xdg-document-portal exited and stayed
  # down because upstream nixpkgs ships them without a Restart policy.
  # Downstream: waybar exited two minutes later, wireplumber's session graph
  # went stale (Focusrite vanished from PipeWire), and the session limped
  # along for four days. Auto-restart turns a transient D-Bus blip back into
  # a transient D-Bus blip instead of a 4-day session degradation.
  #
  # StartLimit* caps prevent a genuinely broken portal (misconfig, missing
  # binary) from looping forever — after 5 failures in 60s systemd gives up
  # and surfaces the failure for manual triage.
  systemd.user.services =
    let
      restartPolicy = {
        serviceConfig = {
          Restart = lib.mkDefault "on-failure";
          RestartSec = lib.mkDefault "5s";
        };
        startLimitBurst = lib.mkDefault 5;
        startLimitIntervalSec = lib.mkDefault 60;
      };
    in
    {
      xdg-desktop-portal = restartPolicy;
      xdg-desktop-portal-gtk = restartPolicy;
      xdg-desktop-portal-hyprland = restartPolicy;
      xdg-document-portal = restartPolicy;
      xdg-permission-store = restartPolicy;
    };
}
