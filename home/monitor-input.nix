# DDC/CI monitor input switching for Dell U4025QW.
# Host-specific – import only on machines with a supported monitor.
{ pkgs, ... }:

{
  home.packages = [
    # Monitor input switching via DDC/CI (Dell U4025QW)
    # VCP code 0x60 = Input Source. Values are monitor-specific;
    # run `ddcutil capabilities` and `ddcutil getvcp 60` to discover them.
    (pkgs.writeShellScriptBin "monitor-input" ''
      #!/usr/bin/env bash
      set -euo pipefail

      usage() {
        echo "Usage: monitor-input <dp|tb>" >&2
        exit 1
      }

      [ $# -eq 1 ] || usage

      case "$1" in
        dp)    value=0x0f; label="DisplayPort" ;;
        tb)    value=0x11; label="Thunderbolt" ;;
        *)     usage ;;
      esac

      if ddcutil setvcp 60 "$value"; then
        notify-send "Monitor Input" "Switched to $label"
      else
        notify-send -u critical "Monitor Input" "Failed to switch to $label"
        exit 1
      fi
    '')
  ];

  wayland.windowManager.hyprland.settings.bindd = [
    # Monitor input switching (DDC/CI)
    "SUPER ALT, 1, Switch monitor to DisplayPort, exec, monitor-input dp"
    "SUPER ALT, 2, Switch monitor to Thunderbolt, exec, monitor-input tb"
  ];
}
