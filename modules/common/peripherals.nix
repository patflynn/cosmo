# Peripherals profile – audio, bluetooth, and health monitoring for
# machines connected to physical hardware (speakers, headsets, etc.).
# Import desktop.nix separately if you also need a window manager.
{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./bluetooth.nix
    ./health.nix
  ];

  modules.bluetooth.enable = true;
  modules.health.enable = true;

  # --- Audio ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true; # Useful for pro audio interfaces like the Focusrite Scarlett
  };
}
