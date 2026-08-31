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

    state_file="$state_dir/deployed-rev"

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
        # was verified against the remote just now without asking GitHub.
        ${set} phase=current "rev=$rev"
        exit 0
      fi

      # The webhook's "cosmo is ahead" becomes visible here, the instant the
      # relay-started run has resolved what ahead means.
      ${set} phase=building "target=$rev" "deployed=$deployed"

      echo "deploying $rev (previously deployed: ''${deployed:-<none>})"
      nixos-rebuild switch --no-write-lock-file --flake "$flake/$rev#$attr"

      # Reached only when the switch succeeded (errexit aborts above
      # otherwise): the state file holds successfully deployed revs, never
      # attempts, so a failed deploy is retried from scratch next run.
      echo "$rev" > "$state_file"
      ${set} phase=current "rev=$rev"

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
