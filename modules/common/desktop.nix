# Desktop profile – audio and bluetooth for physical machines.
# Import workstation.nix separately if you also need a display server.
{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./bluetooth.nix
  ];

  modules.bluetooth.enable = true;

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
