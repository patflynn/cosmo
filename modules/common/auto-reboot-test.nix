# Drives the real reboot-needed / reboot-attempt scripts against canned worlds.
#
# Only `systemctl` and `loginctl` are replaced — by stubs earlier on PATH that
# replay what the current case recorded — so the comparison, the blocker checks
# and the state writing all run for real. The system roots and /dev come from
# the environment seams the scripts document, pointed at trees built here.
#
# The one path this cannot exercise is the reboot itself: the stub records the
# call rather than making it. That half is verified post-merge, by the state
# file appearing at the next kernel-diverging deploy and disappearing after the
# reboot that clears it.
{ pkgs }:

let
  scripts = import ./auto-reboot-scripts.nix { inherit pkgs; };
in
pkgs.runCommand "auto-reboot-tests"
  {
    nativeBuildInputs = [
      scripts.reboot-needed
      scripts.reboot-attempt
      pkgs.jq
    ];
  }
  ''
    mkdir -p stub case
    export CASE="$PWD/case"
    export PATH="$PWD/stub:$PATH"

    # Stands in for systemctl: `is-active --quiet <unit>` consults the case's
    # active-unit list, `reboot` records the call and returns the case's exit.
    cat >stub/systemctl <<'STUB'
    #!${pkgs.runtimeShell}
    case "$1" in
      is-active)
        shift
        [ "$1" = "--quiet" ] && shift
        grep -qxF "$1" "$CASE/active-units" 2>/dev/null && exit 0
        exit 3
        ;;
      reboot)
        echo reboot >>"$CASE/rebooted"
        exit "$(cat "$CASE/reboot-exit" 2>/dev/null || echo 0)"
        ;;
    esac
    exit 1
    STUB

    # Stands in for loginctl: the session list and each session's properties are
    # whatever the case wrote.
    cat >stub/loginctl <<'STUB'
    #!${pkgs.runtimeShell}
    case "$1" in
      list-sessions) cat "$CASE/sessions" 2>/dev/null ;;
      show-session) cat "$CASE/session-$2" 2>/dev/null ;;
    esac
    exit 0
    STUB

    chmod +x stub/systemctl stub/loginctl

    NOW=$(date +%s)

    failures=0
    fail() {
      echo "FAIL $1"
      shift
      for line in "$@"; do echo "     $line"; done
      failures=$((failures + 1))
    }
    ok() { echo "ok   $1"; }

    # Fresh case: empty state dir, empty system roots, no sessions, no agents.
    reset() {
      rm -rf case
      mkdir -p case/state case/booted case/current case/dev case/agents
      : >case/active-units
      : >case/sessions
      export STATE_DIRECTORY="$CASE/state"
      export AUTO_REBOOT_BOOTED="$CASE/booted"
      export AUTO_REBOOT_CURRENT="$CASE/current"
      export AUTO_REBOOT_DEV="$CASE/dev"
      export AUTO_REBOOT_IDLE_SECONDS=3600
      export AUTO_REBOOT_AGENT_MAX_AGE_SECONDS=86400
      export AUTO_REBOOT_BLOCKING_UNITS=""
      export AUTO_REBOOT_AGENT_GLOBS=""
    }

    # world <root> <initrd> <kernel> <kernel-modules> <systemd>
    # Dangling symlinks on purpose: what the comparison reads is the link text.
    world() {
      ln -sfn "/nix/store/$2" "$CASE/$1/initrd"
      ln -sfn "/nix/store/$3" "$CASE/$1/kernel"
      ln -sfn "/nix/store/$4" "$CASE/$1/kernel-modules"
      ln -sfn "/nix/store/$5" "$CASE/$1/systemd"
    }

    # A klaus run record. running=yes leaves duration_ms/merged_at null the way
    # a run in flight does; anything else finalises it the way an exit does.
    run_json() { # run_json <name> <running> <age-seconds>
      local f="$CASE/agents/$1.json"
      if [ "$2" = yes ]; then
        printf '{"id":"%s","duration_ms":null,"cost_usd":null}\n' "$1" >"$f"
      else
        printf '{"id":"%s","duration_ms":1007544,"cost_usd":4.8}\n' "$1" >"$f"
      fi
      touch -m -d "@$((NOW - $3))" "$f"
    }

    # session <id> <class> <state> <tty> <idle-hint> <idle-since-usec>
    session() {
      printf '%s\n' "$1" >>"$CASE/sessions"
      printf 'Class=%s\nState=%s\nTTY=%s\nIdleHint=%s\nIdleSinceHint=%s\n' \
        "$2" "$3" "$4" "$5" "$6" >"$CASE/session-$1"
    }

    # A tty whose atime is <age> seconds old — the figure `w` reads for IDLE.
    tty_idle() { # tty_idle <name> <age-seconds>
      mkdir -p "$(dirname "$CASE/dev/$1")"
      : >"$CASE/dev/$1"
      touch -a -d "@$((NOW - $2))" "$CASE/dev/$1"
    }

    pending()  { [ -f "$CASE/state/state" ]; }
    rebooted() { [ -f "$CASE/rebooted" ]; }
    reason()   { sed -n 's/^reason=//p' "$CASE/state/last-blocked" 2>/dev/null; }
    since()    { sed -n 's/^since=//p' "$CASE/state/state" 2>/dev/null; }
    diverged() { sed -n 's/^diverged=//p' "$CASE/state/state" 2>/dev/null; }

    echo "--- reboot-needed ---------------------------------------------------"

    reset
    world booted  initrd-1 kernel-1 modules-1 systemd-1
    world current initrd-1 kernel-1 modules-1 systemd-1
    reboot-needed >/dev/null
    if pending; then fail "identical worlds -> nothing pending" "state: $(cat "$CASE/state/state")"; else
      ok "identical worlds -> nothing pending"; fi

    reset
    world booted  initrd-1 kernel-1 modules-1 systemd-1
    world current initrd-2 kernel-2 modules-2 systemd-1
    reboot-needed >/dev/null
    if pending && [ "$(diverged)" = "initrd kernel kernel-modules" ]; then
      ok "a new kernel -> pending, naming the parts that moved"
    else fail "a new kernel -> pending, naming the parts that moved" "diverged: $(diverged)"; fi

    # The skew this host actually drifted into: same kernel, new PID 1.
    reset
    world booted  initrd-1 kernel-1 modules-1 systemd-261
    world current initrd-1 kernel-1 modules-1 systemd-261.1
    reboot-needed >/dev/null
    if pending && [ "$(diverged)" = "systemd" ]; then
      ok "a new systemd alone -> pending"
    else fail "a new systemd alone -> pending" "diverged: $(diverged)"; fi

    # The age the widget escalates on is the age of the split, so a later check
    # must not reset it — even as the diverging parts change underneath.
    printf 'since=%s\ndiverged=%s\n' "$((NOW - 500000))" "systemd" >"$CASE/state/state"
    world current initrd-9 kernel-9 modules-9 systemd-261.1
    reboot-needed >/dev/null
    if [ "$(since)" = "$((NOW - 500000))" ] && [ "$(diverged)" = "initrd kernel kernel-modules systemd" ]; then
      ok "a re-check keeps the first-detected timestamp and refreshes the parts"
    else fail "a re-check keeps the first-detected timestamp and refreshes the parts" \
      "since: $(since) (expected $((NOW - 500000)))" "diverged: $(diverged)"; fi

    # How the state clears itself after the reboot: nothing else has to.
    reset
    world booted  initrd-1 kernel-1 modules-1 systemd-1
    world current initrd-1 kernel-1 modules-1 systemd-1
    printf 'since=%s\ndiverged=kernel\n' "$NOW" >"$CASE/state/state"
    printf 'at=%s\nreason=stale\n' "$NOW" >"$CASE/state/last-blocked"
    reboot-needed >/dev/null
    if pending || [ -f "$CASE/state/last-blocked" ]; then
      fail "worlds converge -> state and last-blocked both cleared"
    else ok "worlds converge -> state and last-blocked both cleared"; fi

    echo "--- reboot-attempt --------------------------------------------------"

    # Nothing pending is the steady state; it must not touch anything.
    reset
    reboot-attempt >/dev/null
    if rebooted || [ -f "$CASE/state/last-blocked" ]; then
      fail "nothing pending -> no reboot, no blocked record"
    else ok "nothing pending -> no reboot, no blocked record"; fi

    # Everything below is pending.
    arm() {
      printf 'since=%s\ndiverged=kernel\n' "$((NOW - 86400))" >"$CASE/state/state"
    }

    reset; arm
    export AUTO_REBOOT_BLOCKING_UNITS="cosmo-rebuild.service restic-backups-valley.service"
    printf 'restic-backups-valley.service\n' >"$CASE/active-units"
    reboot-attempt >/dev/null
    if ! rebooted && [ "$(reason)" = "restic-backups-valley.service is running" ]; then
      ok "backup running -> deferred, naming the unit"
    else fail "backup running -> deferred, naming the unit" "reason: $(reason)"; fi

    reset; arm
    export AUTO_REBOOT_AGENT_GLOBS="$CASE/agents/*.json"
    run_json 20260825-0732-99333f00 yes 600
    reboot-attempt >/dev/null
    if ! rebooted && [ "$(reason)" = "klaus run 20260825-0732-99333f00 in progress" ]; then
      ok "agent run in flight -> deferred, naming the run"
    else fail "agent run in flight -> deferred, naming the run" "reason: $(reason)"; fi

    reset; arm
    export AUTO_REBOOT_AGENT_GLOBS="$CASE/agents/*.json"
    run_json finished no 600
    reboot-attempt >/dev/null
    if rebooted; then ok "a finished run does not defer"; else
      fail "a finished run does not defer" "reason: $(reason)"; fi

    # A run that died before it was ever finalised keeps null fields forever;
    # the age bound is what stops it deferring reboots for good.
    reset; arm
    export AUTO_REBOOT_AGENT_GLOBS="$CASE/agents/*.json"
    run_json abandoned yes 200000
    reboot-attempt >/dev/null
    if rebooted; then ok "a run record older than the age bound does not defer"; else
      fail "a run record older than the age bound does not defer" "reason: $(reason)"; fi

    reset; arm
    export AUTO_REBOOT_AGENT_GLOBS="$CASE/agents/*.json"
    printf 'not json at all\n' >"$CASE/agents/corrupt.json"
    reboot-attempt >/dev/null
    if rebooted; then ok "an unreadable run record is not a running one"; else
      fail "an unreadable run record is not a running one" "reason: $(reason)"; fi

    # The live shape on this host: a wayland session logind tracks no idleness
    # for, whose tty atime is the only real signal.
    reset; arm
    session 2 user active tty1 no 0
    tty_idle tty1 300
    reboot-attempt >/dev/null
    if ! rebooted && [ "$(reason)" = "session 2 (tty1) idle under 60m" ]; then
      ok "a session whose tty was touched 5m ago -> deferred"
    else fail "a session whose tty was touched 5m ago -> deferred" "reason: $(reason)"; fi

    reset; arm
    session 2 user active tty1 no 0
    tty_idle tty1 260000
    reboot-attempt >/dev/null
    if rebooted; then ok "a session idle for days -> reboot, despite State=active"; else
      fail "a session idle for days -> reboot, despite State=active" "reason: $(reason)"; fi

    # Where logind does maintain the hint, it wins over the tty atime.
    reset; arm
    session 5 user online pts/3 no "$(((NOW - 260000) * 1000000))"
    tty_idle pts/3 260000
    reboot-attempt >/dev/null
    if ! rebooted && [ "$(reason)" = "session 5 (pts/3) idle under 60m" ]; then
      ok "IdleHint=no outranks a long-idle tty"
    else fail "IdleHint=no outranks a long-idle tty" "reason: $(reason)"; fi

    reset; arm
    session 5 user online pts/3 yes "$(((NOW - 7200) * 1000000))"
    tty_idle pts/3 60
    reboot-attempt >/dev/null
    if rebooted; then ok "IdleHint=yes for 2h outranks a freshly touched tty"; else
      fail "IdleHint=yes for 2h outranks a freshly touched tty" "reason: $(reason)"; fi

    reset; arm
    session 1 manager active "" no 0
    session 9 user closing pts/1 no 0
    reboot-attempt >/dev/null
    if rebooted; then ok "manager and closing sessions are not people"; else
      fail "manager and closing sessions are not people" "reason: $(reason)"; fi

    reset; arm
    session 7 user online "" no 0
    reboot-attempt >/dev/null
    if ! rebooted && [ "$(reason)" = "session 7 (no tty) idleness unknown" ]; then
      ok "a session with no idleness signal at all -> deferred, not assumed idle"
    else fail "a session with no idleness signal at all -> deferred, not assumed idle" "reason: $(reason)"; fi

    reset; arm
    reboot-attempt >/dev/null
    if rebooted && [ -z "$(reason)" ]; then
      ok "nothing running -> reboot, nothing recorded as blocking"
    else fail "nothing running -> reboot, nothing recorded as blocking" "reason: $(reason)"; fi

    # An inhibitor lock refusing the non-forced reboot is a blocker like any
    # other, and has to become visible like one.
    reset; arm
    printf '1' >"$CASE/reboot-exit"
    reboot-attempt >/dev/null
    case "$(reason)" in
      "systemctl reboot refused"*) ok "a refused reboot is recorded as a blocked attempt" ;;
      *) fail "a refused reboot is recorded as a blocked attempt" "reason: $(reason)" ;;
    esac

    if [ "$failures" -ne 0 ]; then
      echo "$failures check(s) failed"
      exit 1
    fi
    touch $out
  ''
