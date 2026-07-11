{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.crashCapture;

  # High-frequency telemetry sample. Runs every ~30s (see the timer below) and
  # writes ONE compact line to the journal under SyslogIdentifier=crash-telemetry.
  # journald on this host stores persistently (services.journald.storage =
  # "persistent" → /var/log/journal), so the samples survive the reboot. After
  # the NEXT silent freeze the journal tail therefore shows the thermal + load
  # trajectory in the final seconds before death — directly answering "was it
  # heat, a runaway load, or swap thrash?", which is exactly the data we lacked
  # when classic-laddie locked up mid-stream on 2026-07-08.
  telemetryScript = pkgs.writeShellScript "crash-telemetry" ''
    # Force the C locale so `free`, `sensors`, `ps`, etc. emit their canonical
    # English output. Under a localized LC_* the field labels and decimal
    # separators can differ, which would silently break the awk parsing below.
    export LC_ALL=C

    # Restricted PATH of cheap sampling tools (all already pulled in by
    # modules/common/health.nix, so no new closure cost). /run/current-system/sw/bin
    # is appended so the system-wide `nvidia-smi` — shipped by the NVIDIA driver's
    # `.bin` output, not part of nixpkgs' makeBinPath set — is found at runtime.
    PATH="${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          procps
          lm_sensors
          gawk
        ]
      )
    }:/run/current-system/sw/bin:$PATH"

    # --- CPU package/CCD temperatures ---
    # k10temp on the Zen 3 5950X exposes Tctl (control temp) and Tccd1/Tccd2 (per-
    # die). Emitted compact as "Tctl=+52.4°C Tccd1=+48.5°C ..." so a lockup shows
    # the thermal ramp, not a single snapshot.
    cpu=$(sensors 2>/dev/null \
      | awk '/^(Tctl|Tdie|Tccd[0-9]):/ {name=$1; sub(/:$/, "", name); printf "%s=%s ", name, $2}')
    [ -n "$cpu" ] || cpu="unavailable"

    # --- GPU temperature / utilisation / VRAM used ---
    # Guarded: nvidia-smi can be momentarily absent (e.g. during a driver reload),
    # and the sampler must keep logging the CPU/load side rather than fail the unit.
    if command -v nvidia-smi >/dev/null 2>&1; then
      gpu=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used \
        --format=csv,noheader 2>/dev/null | head -1)
      [ -n "$gpu" ] || gpu="unavailable"
    else
      gpu="unavailable"
    fi

    # --- 1-minute load average ---
    load=$(cut -d' ' -f1 /proc/loadavg)

    # --- Memory and swap usage (used/total, human units) ---
    mem=$(free -h | awk '/^Mem:/  {print $3 "/" $2}')
    swap=$(free -h | awk '/^Swap:/ {print $3 "/" $2}')

    # --- Single top CPU-consuming process (cheap ps snapshot, no sampling window) ---
    # pcpu first so $1 is always the CPU percentage; the rest of the line is the
    # process name, reconstructed after stripping the leading gap. Ordering comm
    # first would misalign $2 whenever a process name contains spaces.
    top=$(ps -eo pcpu=,comm= --sort=-pcpu 2>/dev/null | head -1 | awk '{pcpu=$1; $1=""; sub(/^[ \t]+/, ""); print $0 "(" pcpu "%)"}')

    echo "cpu[$cpu] gpu[$gpu] load=$load mem=$mem swap=$swap top=$top"
  '';
in
{
  options.modules.crashCapture = {
    enable = lib.mkEnableOption "Crash-capture / hang-recovery hardening (panic-on-lockup, high-frequency telemetry, pstore archival)";
  };

  config = lib.mkIf cfg.enable {
    # ---------------------------------------------------------------------------
    # (1) Auto-recover + turn detectable lockups into reboots
    # ---------------------------------------------------------------------------
    # panic=20: after ANY kernel panic, reboot 20s later instead of sitting dead
    # forever waiting on a physical hard reset (classic-laddie sat wedged for ~3
    # days after the 2026-07-08 freeze). This list merges with the existing
    # `boot.kernelParams = [ "usbcore.autosuspend=-1" ]` in
    # hosts/classic-laddie/hardware.nix — NixOS concatenates kernelParams, no conflict.
    #
    # NOTE: intentionally NOT wrapped in lib.mkDefault. kernelParams is a list
    # option: definitions concatenate at equal override priority, but a plain
    # (priority-100) definition from a host wins outright over a mkDefault
    # (priority-1000) one, DROPPING it entirely rather than merging. Since
    # classic-laddie's hardware.nix already sets kernelParams plainly, mkDefault
    # here would silently delete "panic=20" on exactly the host this targets.
    boot.kernelParams = [ "panic=20" ];

    # Convert the failure modes we CAN detect into panics, so panic=20 can recover
    # them and any pstore backend can capture them:
    boot.kernel.sysctl = {
      # An oops is already-corrupted kernel state; continuing risks silent damage.
      # Panic instead so we reboot cleanly and leave a trace.
      "kernel.panic_on_oops" = lib.mkDefault 1;

      # softlockup: a CPU stuck in kernel mode >20s without scheduling. The soft
      # watchdog already detects it; this makes it panic-and-reboot instead of
      # only logging a warning into a journal nothing will ever read post-freeze.
      "kernel.softlockup_panic" = lib.mkDefault 1;

      # hardlockup: a CPU wedged with interrupts disabled, caught by the NMI
      # watchdog (already enabled — nmi_watchdog=1). This is the single most
      # valuable setting for our symptom: a true silent hard lockup is precisely
      # what the NMI detector is for. Without this it only WARNs; with it the box
      # panics and — via panic=20 — reboots itself instead of hanging until a
      # human power-cycles it.
      "kernel.hardlockup_panic" = lib.mkDefault 1;

      # DELIBERATELY OMITTED: kernel.hung_task_panic.
      # hung_task fires on tasks stuck in uninterruptible D-state on I/O — which is
      # EXPECTED here, not a fault. modules/common/system.nix documents a benign
      # ~122s hung_task_timeout during NVMe swap-in (the 2026-04-29
      # shmem_swapin_folio D-state stall, since mitigated with zram). Panicking on
      # hung_task would reboot the box mid-build / mid-swap on a non-crash. The
      # hard/soft-lockup detectors above target true CPU lockups and do NOT
      # false-fire on I/O waits, so they are the safe subset to panic on.
    };

    # ---------------------------------------------------------------------------
    # (2) High-frequency telemetry to the persistent journal
    # ---------------------------------------------------------------------------
    # The highest-value, zero-risk diagnostic: the periodic health check in
    # health.nix only samples HOURLY, so on 2026-07-08 we had no idea what the
    # box was doing in the minutes before it froze. This samples every ~30s.
    systemd.services.crash-telemetry = {
      description = "Sample CPU/GPU thermals + load for crash post-mortem";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = telemetryScript;
        # Distinct identifier so the whole trajectory is filterable after a
        # freeze with: journalctl -t crash-telemetry
        SyslogIdentifier = "crash-telemetry";
        # Keep the sampler out of the way of real work — it must observe load,
        # never add to it.
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.crash-telemetry = {
      description = "Trigger crash-telemetry sample every 30s";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30s";
        # systemd's default AccuracySec is 1 minute, which would coalesce our 30s
        # cadence back to roughly one sample per minute. Tighten it so we actually
        # get sub-minute resolution right before a freeze.
        AccuracySec = "1s";
      };
    };

    # ---------------------------------------------------------------------------
    # (3) Best-effort persistent panic capture (pstore)
    # ---------------------------------------------------------------------------
    # NixOS already enables systemd-pstore.service (wantedBy = sysinit.target), so
    # on the next boot anything a pstore backend captured in /sys/fs/pstore is
    # archived to /var/lib/systemd/pstore automatically. We make the archival
    # policy explicit (and self-documenting) rather than relying on systemd's
    # compiled-in defaults:
    #   Storage=external → copy panic records into /var/lib/systemd/pstore
    #   Unlink=yes       → clear /sys/fs/pstore afterwards so the (tiny, e.g.
    #                      EFI-variable) backend has room for the next panic.
    #
    # Which backend actually captures the panic is board-dependent. On this AM4
    # box efi_pstore (panic dmesg → EFI variables) is the likely one; ACPI ERST
    # may or may not be exposed by consumer AM4 firmware. Crucially, (1) above is
    # what makes this useful at all: a truly silent hard lockup executes no panic
    # path and writes nothing — but with hardlockup_panic=1 the NMI watchdog now
    # turns that lockup INTO a panic, which a backend can then record before the
    # panic=20 warm reboot preserves it.
    #
    # ramoops (pstore/ram) is DELIBERATELY NOT configured: on x86 it needs a
    # hard-coded reserved physical address (mem_address/mem_size) that is
    # board-specific and risky to guess; shipping a pinned-address guess could
    # corrupt memory the firmware/kernel actually uses. The telemetry-to-journal
    # path in (2) is already a solid reboot-surviving capture, and netconsole to
    # an always-on LAN host is the recommended follow-up for guaranteed hard-hang
    # capture (see PR description, Track B).
    environment.etc."systemd/pstore.conf".text = lib.mkDefault ''
      [PStore]
      Storage=external
      Unlink=yes
    '';
  };
}
