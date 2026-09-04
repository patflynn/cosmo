# The two halves of the cosmo-rebuild unit, kept out of the module so the
# check (./test.nix) can drive the real scripts with stub git and
# nixos-rebuild binaries and assert the transitions they author.
#
# Every root and remote is read from the environment with a production default,
# the same seam auto-reboot-scripts.nix takes; ./default.nix is what turns that
# seam into options, setting COSMO_REBUILD_{REPO,FLAKE,ATTR} on the unit from
# `modules.converge.*`. The defaults below stay the documented fallback — what
# these scripts do when run by hand or by the check (systemd supplies
# STATE_DIRECTORY).
#
# Both scripts author state only through `converge-status set`, which owns the
# schema. Nothing else ever writes $STATE_DIRECTORY/status.
{ pkgs, converge-status }:

let
  set = ''${converge-status}/bin/converge-status set --status-file "$state_dir/status"'';
in
{
  # --- half one: converge to the tip of main --------------------------------
  cosmo-rebuild = pkgs.writeShellScriptBin "cosmo-rebuild" ''
    # errexit is what makes deployed-rev mean "switched cleanly": every write
    # below is reached only because the switch above it did not abort. pipefail
    # so a failed ls-remote isn't masked by cut exiting 0.
    set -euo pipefail

    state_dir="''${STATE_DIRECTORY:-/var/lib/cosmo-rebuild}"
    repo="''${COSMO_REBUILD_REPO:-https://github.com/patflynn/cosmo.git}"
    flake="''${COSMO_REBUILD_FLAKE:-github:patflynn/cosmo}"
    attr="''${COSMO_REBUILD_ATTR:-classic-laddie}"
    booted="''${COSMO_REBUILD_BOOTED:-/run/booted-system}"
    reboot_dir="''${COSMO_REBUILD_REBOOT_DIR:-/var/lib/reboot-pending}"

    state_file="$state_dir/deployed-rev"
    mirror="$state_dir/mirror.git"

    # The rev's commit date and subject, as `set` args in $meta_args. The flake
    # builds from github: tarballs, which carry no commit message, so a bare
    # shallow mirror in the state dir holds one: `fetch` looks the rev up over
    # the network the first time it is seen, and nothing does after. Best effort
    # throughout — a lookup that comes back empty is a tooltip without a
    # subject (`set` carries the last one forward), never a failed run.
    meta_args=()
    load_meta() { # load_meta <rev> [fetch]
      meta_args=()
      local m ct subj
      [ -d "$mirror" ] || git init --bare -q "$mirror" 2>/dev/null || return 0
      m=$(git -C "$mirror" log -1 --format='%ct%x09%s' "$1" 2>/dev/null) || m=""
      if [ -z "$m" ] && [ "''${2:-}" = fetch ]; then
        git -C "$mirror" fetch --depth=1 -q "$repo" refs/heads/main 2>/dev/null || return 0
        m=$(git -C "$mirror" log -1 --format='%ct%x09%s' "$1" 2>/dev/null) || m=""
      fi
      ct=$(printf '%s' "$m" | cut -f1)
      subj=$(printf '%s' "$m" | cut -s -f2-)
      case "$ct" in "" | *[!0-9]*) return 0 ;; esac
      meta_args=("committed=$ct")
      [ -n "$subj" ] && meta_args+=("subject=$subj")
      return 0
    }

    for _ in 1 2 3 4 5; do
      # Resolve the tip first, then deploy exactly that rev — what we compare
      # is what we switch to. `|| rev=""` holds errexit off just here so a
      # failed ls-remote lands in the branch below with the rest of the ways
      # the remote can come back unusable, rather than aborting unexplained.
      rev=$(git ls-remote "$repo" refs/heads/main | cut -f1) || rev=""

      # First run: no state file, $deployed stays empty, never equals $rev, so
      # we proceed to deploy.
      deployed=""
      if [ -f "$state_file" ]; then
        deployed=$(cat "$state_file")
      fi

      # The one failure this script can describe better than systemd's
      # ExecStopPost can: the host could not reach the remote at all, which is
      # also the failure that leaves the widget with no other way to know.
      if [ -z "$rev" ]; then
        ${set} phase=failed "deployed=$deployed" \
          "detail=could not resolve refs/heads/main on the remote"
        echo "could not resolve refs/heads/main on the remote" >&2
        exit 1
      fi

      if [ "$rev" = "$deployed" ]; then
        echo "already at tip $rev"
        # Re-observing the phase, not re-entering it: `set` carries the
        # existing `at` forward and moves `checked`, so the bar learns the host
        # was verified against the remote just now without asking GitHub. The
        # mirror lookup stays local for the same reason: this tick costs the
        # one ls-remote and nothing more.
        load_meta "$rev"
        ${set} phase=current "rev=$rev" "''${meta_args[@]}"
        exit 0
      fi

      # The webhook's "cosmo is ahead" becomes visible here, the instant the
      # relay-started run has resolved what ahead means — with what the target
      # commit is, not just its sha.
      load_meta "$rev" fetch
      ${set} phase=building "target=$rev" "deployed=$deployed" "''${meta_args[@]}"

      echo "deploying $rev (previously deployed: ''${deployed:-<none>})"

      # Build the target first so we can check for incompatible kernel/driver
      # divergence before activating it. We hold the result symlink in $build_dir
      # as a GC root until activation completes.
      build_dir=$(mktemp -d "$state_dir/build.XXXXXX")
      target=""
      if (
        cd "$build_dir"
        nixos-rebuild build --no-write-lock-file --flake "$flake/$rev#$attr"
      ); then
        target=$(readlink -f "$build_dir/result" 2>/dev/null || true)
      fi

      if [ -z "$target" ]; then
        rm -rf "$build_dir"
        echo "could not resolve built target system" >&2
        exit 1
      fi

      diverged=""
      for part in initrd kernel kernel-modules systemd; do
        a=$(readlink "$booted/$part" 2>/dev/null) || a="<missing>"
        b=$(readlink "$target/$part" 2>/dev/null) || b="<missing>"
        [ "$a" = "$b" ] || diverged="''${diverged:+$diverged }$part"
      done

      if [ -n "$diverged" ]; then
        echo "target diverged from booted system ($diverged); staging with boot instead of live switch"
        nixos-rebuild boot --no-write-lock-file --flake "$flake/$rev#$attr"

        mkdir -p "$reboot_dir"
        state="$reboot_dir/state"
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
      else
        echo "target matches booted kernel/systemd; applying live switch"
        nixos-rebuild switch --no-write-lock-file --flake "$flake/$rev#$attr"
        rm -f "$reboot_dir/state" "$reboot_dir/last-blocked"
      fi

      rm -rf "$build_dir"

      # Reached only when the switch/boot succeeded (errexit aborts above
      # otherwise): the state file holds successfully deployed revs, never
      # attempts, so a failed deploy is retried from scratch next run.
      echo "$rev" > "$state_file"
      # Same rev the building record named, so its metadata is already loaded.
      ${set} phase=current "rev=$rev" "''${meta_args[@]}"

      # Loop: main may have moved while the build ran — converge again.
    done

    echo "main moved during all 5 converge iterations; leaving the rest to the next run" >&2
  '';

  # --- half two: how the run ended, from systemd's side ---------------------
  # ExecStopPost, so the phases that are not an aborted `bash -e` are captured
  # too: TimeoutStartSec expiring mid-switch, a kill, a crashed shell. None of
  # those give the script above a chance to say anything.
  cosmo-rebuild-result = pkgs.writeShellScriptBin "cosmo-rebuild-result" ''
    set -uo pipefail

    state_dir="''${STATE_DIRECTORY:-/var/lib/cosmo-rebuild}"

    # systemd runs this on every exit, success included, where the loop has
    # already recorded `current`. --unless-terminal covers the other way a run
    # ends having said its piece: a script-authored failure whose detail line
    # is strictly better than "exit-code".
    if [ "''${SERVICE_RESULT:-}" = success ]; then
      exit 0
    fi

    exec ${set} --unless-terminal phase=failed \
      "detail=''${SERVICE_RESULT:-unknown} (exit ''${EXIT_STATUS:-?})"
  '';
}
