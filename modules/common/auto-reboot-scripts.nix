# The two halves of modules/common/auto-reboot.nix, kept out of the module so
# the test (modules/common/auto-reboot-test.nix) can drive the real scripts.
#
# Every root and threshold is read from the environment with a production
# default, which is what lets the tests point the scripts at canned trees. The
# unit sets only the thresholds; nothing in production overrides a root.
{ pkgs }:

{
  # --- half one: has the booted world diverged from the deployed one? --------
  reboot-needed = pkgs.writeShellScriptBin "reboot-needed" ''
    # No `set -e`: a missing symlink on either side is information, not an
    # error, and every probe below is allowed to come back empty.
    set -uo pipefail

    state_dir="''${STATE_DIRECTORY:-/var/lib/reboot-pending}"
    booted="''${AUTO_REBOOT_BOOTED:-/run/booted-system}"
    current="''${AUTO_REBOOT_CURRENT:-/nix/var/nix/profiles/system}"
    [ -e "$current" ] || current="''${AUTO_REBOOT_CURRENT:-/run/current-system}"

    state="$state_dir/state"
    blocked="$state_dir/last-blocked"

    # The comparison nixpkgs' system.autoUpgrade.allowReboot makes — readlink
    # of initrd, kernel and kernel-modules — plus systemd, because a systemd
    # whose store path moved is a PID 1 the running one cannot become without a
    # reboot, and that skew is what this host actually drifted into.
    diverged=""
    for part in initrd kernel kernel-modules systemd; do
      a=$(readlink "$booted/$part" 2>/dev/null) || a="<missing>"
      b=$(readlink "$current/$part" 2>/dev/null) || b="<missing>"
      [ "$a" = "$b" ] || diverged="''${diverged:+$diverged }$part"
    done

    mkdir -p "$state_dir"

    if [ -z "$diverged" ]; then
      # Includes the run right after the reboot, which is how the state clears
      # itself: nothing else ever has to remember to.
      [ -e "$state" ] && echo "booted system matches the deployed one; clearing reboot-pending state"
      rm -f "$state" "$blocked"
      exit 0
    fi

    # First detection wins. What the widget escalates on is how long the split
    # has existed, not how long since the last check — so an existing timestamp
    # is carried forward even as the diverging parts change under it.
    since=""
    [ -f "$state" ] && since=$(sed -n 's/^since=//p' "$state" | head -n 1)
    case "$since" in
      "" | *[!0-9]*) since=$(date +%s) ;;
    esac

    {
      printf 'since=%s\n' "$since"
      printf 'diverged=%s\n' "$diverged"
    } >"$state.tmp"
    mv "$state.tmp" "$state"

    echo "reboot pending since $(date -d "@$since" -Is 2>/dev/null || echo "@$since"): $diverged differ between the booted and deployed systems"
  '';

  # --- half two: reboot now, or record what stopped us ----------------------
  reboot-attempt = pkgs.writeShellScriptBin "reboot-attempt" ''
    set -uo pipefail

    state_dir="''${STATE_DIRECTORY:-/var/lib/reboot-pending}"
    dev_dir="''${AUTO_REBOOT_DEV:-/dev}"
    idle_seconds="''${AUTO_REBOOT_IDLE_SECONDS:-3600}"
    agent_max_age="''${AUTO_REBOOT_AGENT_MAX_AGE_SECONDS:-86400}"
    blocking_units="''${AUTO_REBOOT_BLOCKING_UNITS:-}"
    agent_globs="''${AUTO_REBOOT_AGENT_GLOBS:-}"

    state="$state_dir/state"
    blocked="$state_dir/last-blocked"

    [ -f "$state" ] || {
      echo "no reboot pending"
      exit 0
    }

    now=$(date +%s)

    # Blocked is a normal outcome, so the unit exits 0. The record is the point:
    # a deferral nobody can see is indistinguishable from a feature that never
    # ran, and this file is what the waybar module reads.
    record_blocked() {
      mkdir -p "$state_dir"
      {
        printf 'at=%s\n' "$now"
        printf 'reason=%s\n' "$1"
      } >"$blocked.tmp"
      mv "$blocked.tmp" "$blocked"
      echo "reboot deferred: $1"
      exit 0
    }

    # --- blocker: work that must not be interrupted --------------------------
    for unit in $blocking_units; do
      if systemctl is-active --quiet "$unit"; then
        record_blocked "$unit is running"
      fi
    done

    # --- blocker: a klaus agent run in flight --------------------------------
    # klaus records no status field; `klaus status` derives "running" from a run
    # having neither a duration nor a merge, and so do we. Records untouched for
    # longer than the age bound are treated as abandoned, so a run that died
    # before it was ever finalised cannot defer reboots forever. jq's exit
    # status carries the predicate and a parse failure alike — an unreadable run
    # record is not a running one.
    for glob in $agent_globs; do
      for f in $glob; do
        [ -f "$f" ] || continue
        mtime=$(stat -c %Y "$f" 2>/dev/null) || continue
        [ $((now - mtime)) -le "$agent_max_age" ] || continue
        if ${pkgs.jq}/bin/jq -e '(.duration_ms == null) and (.merged_at == null)' "$f" >/dev/null 2>&1; then
          record_blocked "klaus run $(basename "$f" .json) in progress"
        fi
      done
    done

    # --- blocker: someone is at the machine ----------------------------------
    # Idle comes from logind where it maintains the hint, and otherwise from the
    # session tty's atime — the figure `w` prints in its IDLE column.
    #
    # Imperfect, knowingly: the Hyprland session does not call SetIdleHint, and
    # a Wayland session's controlling tty sees no keystrokes, so a user working
    # in the compositor can still read as idle here. The reboot below is
    # non-forced for exactly that reason — it goes through logind, so an
    # inhibitor lock (which a session that cares takes) still stops it, and a
    # refusal is recorded like any other blocker.
    for id in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
      props=$(loginctl show-session "$id" -p Class -p State -p TTY -p IdleHint -p IdleSinceHint 2>/dev/null) || continue
      class=$(printf '%s\n' "$props" | sed -n 's/^Class=//p' | head -n 1)
      sstate=$(printf '%s\n' "$props" | sed -n 's/^State=//p' | head -n 1)
      tty=$(printf '%s\n' "$props" | sed -n 's/^TTY=//p' | head -n 1)
      hint=$(printf '%s\n' "$props" | sed -n 's/^IdleHint=//p' | head -n 1)
      since_us=$(printf '%s\n' "$props" | sed -n 's/^IdleSinceHint=//p' | head -n 1)

      # Only people. `manager` is the per-user systemd instance and `greeter`
      # is the login screen; neither is anyone to reboot out from under.
      [ "$class" = "user" ] || continue
      [ "$sstate" != "closing" ] || continue

      # A zero IdleSinceHint means logind is not tracking this session at all,
      # not that it went idle at the epoch.
      idle=""
      case "$since_us" in
        "" | 0 | *[!0-9]*) ;;
        *)
          if [ "$hint" = "yes" ]; then
            idle=$((now - since_us / 1000000))
          else
            idle=0
          fi
          ;;
      esac

      if [ -z "$idle" ] && [ -n "$tty" ]; then
        atime=$(stat -c %X "$dev_dir/$tty" 2>/dev/null) && idle=$((now - atime))
      fi

      # Unknown idleness blocks: not knowing whether someone is there is not the
      # same as knowing they aren't, and the widget makes a stuck deferral loud.
      if [ -z "$idle" ]; then
        record_blocked "session $id (''${tty:-no tty}) idleness unknown"
      elif [ "$idle" -lt "$idle_seconds" ]; then
        record_blocked "session $id (''${tty:-no tty}) idle under $((idle_seconds / 60))m"
      fi
    done

    echo "nothing blocking; rebooting into the deployed system"
    # Deliberately not `--force`: this goes through logind, so inhibitor locks
    # and the ordinary unit-stop path both apply. A refusal is a blocker like
    # any other and gets recorded as one.
    if systemctl reboot; then
      exit 0
    fi
    record_blocked "systemctl reboot refused (inhibitor lock or logind policy)"
  '';
}
