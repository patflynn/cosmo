{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.health;

  # Health check script that runs hourly and logs to the journal.
  # Sends a desktop notification via notify-send if any issues are found.
  healthCheckScript = pkgs.writeShellScript "health-check" ''
    PATH="${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          gnugrep
          rasdaemon
          smartmontools
          lm_sensors
          zfs
          libnotify
        ]
      )
    }:$PATH"
    issues=""

    # --- rasdaemon: check for memory controller / hardware errors ---
    if command -v ras-mc-ctl &>/dev/null; then
      error_count=$(ras-mc-ctl --error-count 2>/dev/null | grep -v "No .* errors" | grep -c '[0-9]' || true)
      if [ "$error_count" -gt 0 ]; then
        issues="$issues\n- rasdaemon reports $error_count error source(s)"
      fi
    fi

    # --- ZFS pool status ---
    if command -v zpool &>/dev/null; then
      unhealthy=$(zpool status 2>/dev/null | grep -c -E "DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED" || true)
      if [ "$unhealthy" -gt 0 ]; then
        issues="$issues\n- ZFS pool has unhealthy vdevs"
      fi
    fi

    # --- SMART disk health ---
    if command -v smartctl &>/dev/null; then
      for dev in /dev/sd? /dev/nvme?n?; do
        [ -b "$dev" ] || continue
        if ! smartctl -H "$dev" 2>/dev/null | grep -q "PASSED\|OK"; then
          issues="$issues\n- SMART check failed for $dev"
        fi
      done
    fi

    # --- CPU temperature (warn above 90 C) ---
    if command -v sensors &>/dev/null; then
      max_temp=$(sensors 2>/dev/null | grep -oP '\+\K[0-9]+(?=\.[0-9]*°C)' | sort -rn | head -1 || true)
      if [ -n "$max_temp" ] && [ "$max_temp" -ge 90 ]; then
        issues="$issues\n- CPU temperature is ''${max_temp}°C (>= 90°C)"
      fi
    fi

    # --- Report results ---
    if [ -n "$issues" ]; then
      echo "HEALTH CHECK WARNING:$issues"

      # Try to send a desktop notification to logged-in users
      for uid in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}'); do
        runtime_dir="/run/user/$uid"
        if [ -d "$runtime_dir" ]; then
          sudo -u "#$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
            notify-send --urgency=critical "Hardware Health Warning" \
            "$(echo -e "$issues")" 2>/dev/null || true
        fi
      done
    else
      echo "HEALTH CHECK OK: all checks passed"
    fi
  '';
in
{
  options.modules.health = {
    enable = lib.mkEnableOption "Hardware health monitoring (RAM, disk, thermals)";
  };

  config = lib.mkIf cfg.enable {
    # ---------------------------------------------------------------------------
    # rasdaemon — monitor MCE and EDAC errors (critical for catching RAM issues
    # on the Ryzen 9 5950X memory controller, even with non-ECC DIMMs)
    # ---------------------------------------------------------------------------
    hardware.rasdaemon = {
      enable = true;
      record = true; # persist errors to sqlite so ras-mc-ctl can query them
    };

    # ---------------------------------------------------------------------------
    # smartmontools — monitor disk health and send wall notifications on problems
    # ---------------------------------------------------------------------------
    services.smartd = {
      enable = true;
      autodetect = true;
      notifications = {
        wall.enable = true;
        systembus-notify.enable = true;
      };
    };

    # ---------------------------------------------------------------------------
    # lm_sensors — temperature monitoring (uses k10temp for AMD Ryzen CPUs)
    # ---------------------------------------------------------------------------
    # k10temp is auto-loaded by the kernel for Zen 3 (5950X), but we make sure
    # the sensors tooling and diagnostic packages are available.
    environment.systemPackages = with pkgs; [
      lm_sensors # sensor readout (sensors command)
      memtester # on-demand userspace RAM testing
      edac-utils # EDAC sysfs query tools
    ];

    # ---------------------------------------------------------------------------
    # Periodic health check — runs hourly and logs to the journal
    # ---------------------------------------------------------------------------
    systemd.services.health-check = {
      description = "Periodic hardware health check";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthCheckScript;
      };
    };

    systemd.timers.health-check = {
      description = "Run hardware health check every hour";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true; # run immediately if a check was missed (e.g. after sleep)
        RandomizedDelaySec = "5m";
      };
    };
  };
}
