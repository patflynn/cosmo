# Drives the real converge scripts through every transition they author.
#
# Only `git` and `nixos-rebuild` are replaced — by stubs earlier on PATH that
# replay what the current case recorded — so the loop, the deployed-rev rule
# and the real converge-status binary all run for real. What is asserted is the
# state machine: which phase each outcome leaves in the status file, and that
# deployed-rev keeps its write-on-success-only semantics underneath it.
{ pkgs }:

let
  converge-status = pkgs.callPackage ../../pkgs/converge-status { };
  scripts = import ./scripts.nix { inherit pkgs converge-status; };
in
pkgs.runCommand "cosmo-rebuild-tests"
  {
    nativeBuildInputs = [
      scripts.cosmo-rebuild
      scripts.cosmo-rebuild-result
      converge-status
    ];
  }
  ''
    mkdir -p stub
    export PATH="$PWD/stub:$PATH"

    # Stands in for git: only `ls-remote` is reached, and it replays the case's
    # recorded ref line and exit code.
    cat >stub/git <<'STUB'
    #!${pkgs.runtimeShell}
    [ "$1" = ls-remote ] || exit 1
    cat "$CASE/tip" 2>/dev/null
    exit "$(cat "$CASE/git-exit" 2>/dev/null || echo 0)"
    STUB

    # Stands in for the switch and build. It snapshots the status file as it found it,
    # which is the only way to see the `building` phase from outside: by the
    # time the run ends the loop has replaced it.
    cat >stub/nixos-rebuild <<'STUB'
    #!${pkgs.runtimeShell}
    case "$1" in
      build)
        mkdir -p "$CASE/target-system"
        if [ -d "$CASE/target-parts" ]; then
          cp -r "$CASE/target-parts/." "$CASE/target-system/" 2>/dev/null || true
        fi
        ln -sfn "$CASE/target-system" result
        ;;
      switch|boot)
        cp "$STATE_DIRECTORY/status" "$CASE/status-during-switch" 2>/dev/null
        printf '%s\n' "$*" >>"$CASE/switch-args"
        ;;
    esac
    exit "$(cat "$CASE/rebuild-exit" 2>/dev/null || echo 0)"
    STUB

    chmod +x stub/git stub/nixos-rebuild

    A=1a2b3c4d5e6f708192a3b4c5d6e7f80912345678
    B=9f8e7d6c5b4a30291817161514131211100f0e0d

    failures=0
    fail() {
      echo "FAIL $1"
      shift
      for line in "$@"; do echo "     $line"; done
      failures=$((failures + 1))
    }
    ok() { echo "ok   $1"; }

    reset() {
      rm -rf case
      mkdir -p case/state case/booted case/reboot-pending
      export CASE="$PWD/case"
      export STATE_DIRECTORY="$CASE/state"
      export COSMO_REBUILD_BOOTED="$CASE/booted"
      export COSMO_REBUILD_REBOOT_DIR="$CASE/reboot-pending"
      unset SERVICE_RESULT EXIT_STATUS
    }

    booted_part() { # booted_part <part> <store-path>
      mkdir -p "$CASE/booted"
      ln -sfn "/nix/store/$2" "$CASE/booted/$1"
    }
    target_part() { # target_part <part> <store-path>
      mkdir -p "$CASE/target-parts"
      ln -sfn "/nix/store/$2" "$CASE/target-parts/$1"
    }

    tip() { printf '%s\trefs/heads/main\n' "$1" >"$CASE/tip"; }
    deployed() { printf '%s\n' "$1" >"$CASE/state/deployed-rev"; }
    field() { sed -n "s/^$1=//p" "$CASE/state/status" 2>/dev/null; }
    at_switch() { sed -n "s/^$1=//p" "$CASE/status-during-switch" 2>/dev/null; }
    ledger() { cat "$CASE/state/deployed-rev" 2>/dev/null; }

    echo "--- cosmo-rebuild ---------------------------------------------------"

    # The steady state: the hourly tick finds nothing to do and says so. The
    # widget learns the host was verified against the remote just now.
    reset
    tip "$A"
    deployed "$A"
    before=$(date +%s)
    cosmo-rebuild >/dev/null
    if [ "$(field phase)" = current ] && [ "$(field rev)" = "$A" ] && [ "$(field checked)" -ge "$before" ]; then
      ok "tip == deployed -> current, checked moved, no switch"
    else fail "tip == deployed -> current, checked moved, no switch" "status: $(cat "$CASE/state/status")"; fi
    [ -f "$CASE/switch-args" ] && fail "a no-change run must not switch"

    # A push landed. The building record has to exist *while* the switch runs —
    # that is the whole point of authoring it before nixos-rebuild rather than
    # after — and carry both revs, so the bar can say what is being deployed
    # over what.
    reset
    tip "$B"
    deployed "$A"
    cosmo-rebuild >/dev/null
    if [ "$(at_switch phase)" = building ] && [ "$(at_switch target)" = "$B" ] && [ "$(at_switch deployed)" = "$A" ]; then
      ok "a deploy authors building with both revs before switching"
    else fail "a deploy authors building with both revs before switching" \
      "status during switch: $(cat "$CASE/status-during-switch" 2>/dev/null)"; fi

    if [ "$(field phase)" = current ] && [ "$(field rev)" = "$B" ] && [ "$(ledger)" = "$B" ]; then
      ok "a successful switch -> current, and deployed-rev moves with it"
    else fail "a successful switch -> current, and deployed-rev moves with it" \
      "status: $(cat "$CASE/state/status")" "deployed-rev: $(ledger)"; fi

    # A deploy where the target's kernel-modules diverged from the booted system:
    # must invoke `nixos-rebuild boot` rather than `switch`, and record reboot-pending.
    reset
    tip "$B"
    deployed "$A"
    booted_part kernel-modules "mod-v1"
    target_part kernel-modules "mod-v2"
    cosmo-rebuild >/dev/null
    case "$(cat "$CASE/switch-args" 2>/dev/null)" in
      boot*) ok "diverging kernel-modules invokes nixos-rebuild boot" ;;
      *) fail "diverging kernel-modules invokes nixos-rebuild boot" "args: $(cat "$CASE/switch-args" 2>/dev/null)" ;;
    esac
    if [ -f "$CASE/reboot-pending/state" ] && grep -q "diverged=kernel-modules" "$CASE/reboot-pending/state"; then
      ok "boot staging records diverged=kernel-modules in reboot-pending state"
    else
      fail "boot staging records diverged=kernel-modules in reboot-pending state" \
        "state: $(cat "$CASE/reboot-pending/state" 2>/dev/null)"
    fi
    if [ "$(field phase)" = current ] && [ "$(field rev)" = "$B" ] && [ "$(ledger)" = "$B" ]; then
      ok "boot deploy successfully records current phase and updates deployed-rev"
    else
      fail "boot deploy successfully records current phase and updates deployed-rev" \
        "status: $(cat "$CASE/state/status")" "deployed-rev: $(ledger)"; fi

    # A deploy where target matches booted system:
    # must invoke `nixos-rebuild switch` and clear reboot-pending state if present.
    reset
    tip "$B"
    deployed "$A"
    booted_part kernel-modules "mod-v1"
    target_part kernel-modules "mod-v1"
    mkdir -p "$CASE/reboot-pending"
    echo "since=12345" >"$CASE/reboot-pending/state"
    cosmo-rebuild >/dev/null
    case "$(cat "$CASE/switch-args" 2>/dev/null)" in
      switch*) ok "matching kernel-modules invokes nixos-rebuild switch" ;;
      *) fail "matching kernel-modules invokes nixos-rebuild switch" "args: $(cat "$CASE/switch-args" 2>/dev/null)" ;;
    esac
    if [ ! -e "$CASE/reboot-pending/state" ]; then
      ok "switch deploy clears existing reboot-pending state"
    else
      fail "switch deploy clears existing reboot-pending state"
    fi

    # The unresolvable remote: the one failure the script can name better than
    # systemd can, and the one that would otherwise leave the widget with a
    # deployed-rev that still looks converged.
    reset
    tip ""
    printf '1' >"$CASE/git-exit"
    deployed "$A"
    if cosmo-rebuild >/dev/null 2>&1; then
      fail "an unresolvable tip must fail the unit"
    else ok "an unresolvable tip fails the unit"; fi
    case "$(field phase)/$(field detail)" in
      "failed/could not resolve refs/heads/main on the remote")
        ok "an unresolvable tip -> failed, naming the reason" ;;
      *) fail "an unresolvable tip -> failed, naming the reason" "status: $(cat "$CASE/state/status")" ;;
    esac
    [ "$(ledger)" = "$A" ] || fail "a failed run must not touch deployed-rev" "deployed-rev: $(ledger)"

    # A switch that dies: errexit aborts the loop before the deployed-rev
    # write, so the ledger stays at the last rev that switched cleanly and the
    # status is left mid-`building` for ExecStopPost to finish.
    reset
    tip "$B"
    deployed "$A"
    printf '1' >"$CASE/rebuild-exit"
    if cosmo-rebuild >/dev/null 2>&1; then
      fail "a failed switch must fail the unit"
    else ok "a failed switch fails the unit"; fi
    if [ "$(field phase)" = building ] && [ "$(ledger)" = "$A" ]; then
      ok "a failed switch leaves building standing and deployed-rev untouched"
    else fail "a failed switch leaves building standing and deployed-rev untouched" \
      "status: $(cat "$CASE/state/status")" "deployed-rev: $(ledger)"; fi

    echo "--- cosmo-rebuild-result (ExecStopPost) -----------------------------"

    # Continuing the case above: systemd's account of the death, inheriting the
    # revs the run announced. target != deployed is the behind state — laddie
    # knows main moved and knows it is not running it.
    SERVICE_RESULT=exit-code EXIT_STATUS=1 cosmo-rebuild-result
    if [ "$(field phase)" = failed ] && [ "$(field target)" = "$B" ] && [ "$(field deployed)" = "$A" ]; then
      ok "a died-mid-build run -> failed, inheriting target and deployed"
    else fail "a died-mid-build run -> failed, inheriting target and deployed" \
      "status: $(cat "$CASE/state/status")"; fi
    case "$(field detail)" in
      *exit-code*) ok "the failure detail carries systemd's result" ;;
      *) fail "the failure detail carries systemd's result" "detail: $(field detail)" ;;
    esac

    # A run killed by TimeoutStartSec never gets to run a line of the script,
    # which is exactly why this lives in ExecStopPost.
    reset
    tip "$B"
    deployed "$A"
    printf '1' >"$CASE/rebuild-exit"
    cosmo-rebuild >/dev/null 2>&1 || true
    SERVICE_RESULT=timeout EXIT_STATUS=0 cosmo-rebuild-result
    case "$(field phase)/$(field detail)" in
      failed/timeout*) ok "a timeout is captured, not just a bash abort" ;;
      *) fail "a timeout is captured, not just a bash abort" "status: $(cat "$CASE/state/status")" ;;
    esac

    # ExecStopPost runs on success too, where the loop has already recorded the
    # outcome and there is nothing left to say.
    reset
    tip "$A"
    deployed "$A"
    cosmo-rebuild >/dev/null
    SERVICE_RESULT=success EXIT_STATUS=0 cosmo-rebuild-result
    if [ "$(field phase)" = current ]; then
      ok "a successful run is left alone"
    else fail "a successful run is left alone" "status: $(cat "$CASE/state/status")"; fi

    # And the script's own failure record outranks systemd's coarser one.
    reset
    tip ""
    printf '1' >"$CASE/git-exit"
    cosmo-rebuild >/dev/null 2>&1 || true
    SERVICE_RESULT=exit-code EXIT_STATUS=1 cosmo-rebuild-result
    if [ "$(field detail)" = "could not resolve refs/heads/main on the remote" ]; then
      ok "a script-authored failure is not overwritten by exit-code"
    else fail "a script-authored failure is not overwritten by exit-code" "detail: $(field detail)"; fi

    if [ "$failures" -ne 0 ]; then
      echo "$failures check(s) failed"
      exit 1
    fi
    touch $out
  ''
