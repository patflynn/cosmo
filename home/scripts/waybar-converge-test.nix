# Drives the real waybar-converge binary through every state it can report.
#
# Only `ssh` is replaced — by a stub earlier on PATH that replays a recorded
# reply and exit code — so the script's own parsing, precedence and rendering
# all run for real. The two cases the `failed` state exists for (a failure
# hiding behind a rev that still matches main, and a unit flapping between
# activating and failed) are asserted explicitly.
{ pkgs }:

let
  converge = import ./waybar-converge.nix { inherit pkgs; };
in
pkgs.runCommand "waybar-converge-tests"
  {
    nativeBuildInputs = [
      converge
      pkgs.jq
    ];
  }
  ''
    mkdir -p stub case
    export STUB_DIR="$PWD/case"
    export PATH="$PWD/stub:$PATH"

    cat >stub/ssh <<'STUB'
    #!${pkgs.runtimeShell}
    # Stands in for ssh: ignores the destination and the remote block entirely
    # and replays whatever the current case recorded.
    cat "$STUB_DIR/stdout"
    cat "$STUB_DIR/stderr" >&2
    exit "$(cat "$STUB_DIR/exit")"
    STUB
    chmod +x stub/ssh

    # A reply shaped the way the remote block prints it.
    canned() { # canned <rev> <tip> <active> <failed> <log>
      printf 'rev=%s\ntip=%s\nactive=%s\nfailed=%s\nlog=%s\n' "$1" "$2" "$3" "$4" "$5" \
        >"$STUB_DIR/stdout"
      : >"$STUB_DIR/stderr"
      printf '0' >"$STUB_DIR/exit"
    }

    raw() { # raw <exit> <stdout> <stderr>
      printf '%s' "$2" >"$STUB_DIR/stdout"
      printf '%s' "$3" >"$STUB_DIR/stderr"
      printf '%s' "$1" >"$STUB_DIR/exit"
    }

    failures=0
    check() { # check <name> <jq filter>
      local out
      out=$(waybar-converge)
      if printf '%s' "$out" | jq -e "$2" >/dev/null; then
        echo "ok   $1"
      else
        echo "FAIL $1"
        echo "     filter: $2"
        echo "     output: $out"
        failures=$((failures + 1))
      fi
    }

    A=1a2b3c4d5e6f708192a3b4c5d6e7f80912345678
    B=9f8e7d6c5b4a30291817161514131211100f0e0d

    # --- current -------------------------------------------------------------
    canned "$A" "$A" inactive inactive ""
    check "deployed rev matches main -> current" \
      '.class == "current" and (.text | contains("1a2b3c4"))'

    # --- stale ---------------------------------------------------------------
    canned "$A" "$B" inactive inactive ""
    check "deployed rev behind main -> stale" \
      '.class == "stale" and (.text | contains("1a2b3c4")) and (.tooltip | contains("'"$B"'"))'

    # --- rebuilding ----------------------------------------------------------
    canned "$A" "$B" activating inactive "deploying $B (previously deployed: $A)"
    check "unit activating -> rebuilding" \
      '.class == "rebuilding" and (.tooltip | contains("deploying"))'

    # --- failed --------------------------------------------------------------
    canned "$A" "$B" inactive failed "error: builder for '/nix/store/x.drv' failed with exit code 1"
    check "unit failed -> failed, keeping the deployed short rev" \
      '.class == "failed" and (.text | contains("1a2b3c4"))'
    check "failed tooltip carries the journal line" \
      '.tooltip | contains("builder for") and contains("no longer tracking main")'

    # The reason `failed` exists: deployed-rev only moves on success, so a run
    # that dies before main moves again leaves a rev that still matches the
    # tip. Rev comparison alone would call this converged.
    canned "$A" "$A" inactive failed "could not resolve refs/heads/main on the remote"
    check "failed outranks a rev that still matches main" \
      '.class == "failed" and (.tooltip | contains("could not resolve"))'

    # A retrying loop flaps between activating and failed; it must read as
    # activity or failure, never as current.
    canned "$A" "$A" activating failed "deploying $A"
    check "activating wins over a failed last run" '.class == "rebuilding"'

    # Nix build output and structured container logs run long enough to make a
    # tooltip unusable.
    canned "$A" "$B" inactive failed "error: $(printf 'x%.0s' {1..400})"
    check "an overlong journal line is truncated" \
      '.class == "failed" and (.tooltip | contains("…") and (length < 500))'

    # --- unreachable ---------------------------------------------------------
    # ssh's real shape: a warning line, then the diagnostic, then a newline.
    raw 255 "" "Warning: Permanently added 'classic-laddie' to known hosts.
    Permission denied (publickey).
    "
    check "ssh failure -> unreachable, quoting ssh's last diagnostic" \
      '.class == "unreachable" and (.tooltip | contains("Permission denied"))'

    # Same, but the stream ends without a trailing newline.
    raw 255 "" "ssh: connect to host classic-laddie port 22: No route to host"
    check "unterminated ssh diagnostic still reaches the tooltip" \
      '.class == "unreachable" and (.tooltip | contains("No route to host"))'

    raw 0 "not a probe response" ""
    check "unparseable reply -> unreachable" '.class == "unreachable"'

    canned "" "$B" inactive inactive ""
    check "nothing deployed yet -> unreachable, not current or stale" \
      '.class == "unreachable" and (.tooltip | contains("cannot compare"))'

    canned "$A" "" inactive inactive ""
    check "host could not resolve the tip -> unreachable" \
      '.class == "unreachable" and (.tooltip | contains("<unresolved>"))'

    if [ "$failures" -ne 0 ]; then
      echo "$failures check(s) failed"
      exit 1
    fi
    touch $out
  ''
