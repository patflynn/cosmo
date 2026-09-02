# Drives the real waybar-converge stream through the only thing it decides:
# what happens when the ssh carrying the far end's lines goes away.
#
# Only `ssh` is replaced — by a stub earlier on PATH that replays a recorded
# stream and exit code — so the pass-through, the diagnostic harvesting and the
# reconnect loop all run for real. Everything the bar *says* is asserted on the
# far end instead (pkgs/converge-status), which is where deriving it now lives.
{ pkgs }:

let
  converge = import ./waybar-converge.nix {
    inherit pkgs;
    host = "classic-laddie";
  };
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

    # Stands in for ssh: records how it was invoked, replays whatever the
    # current case recorded, and exits with the case's code — the shape of a
    # `converge-status watch` that ran for a while and then lost its host.
    cat >stub/ssh <<'STUB'
    #!${pkgs.runtimeShell}
    printf '%s\n' "$*" >>"$STUB_DIR/argv"
    cat "$STUB_DIR/stdout"
    cat "$STUB_DIR/stderr" >&2
    exit "$(cat "$STUB_DIR/exit")"
    STUB
    chmod +x stub/ssh

    # Two attempts and no delay between them: the loop is unbounded in
    # production, and these seams are the only way to watch it come back.
    export WAYBAR_CONVERGE_ATTEMPTS=2
    export WAYBAR_CONVERGE_MIN_BACKOFF=0
    export WAYBAR_CONVERGE_MAX_BACKOFF=0

    failures=0
    fail() {
      echo "FAIL $1"
      shift
      for line in "$@"; do echo "     $line"; done
      failures=$((failures + 1))
    }
    ok() { echo "ok   $1"; }

    reset() { # reset <exit> <stdout> <stderr>
      rm -f "$STUB_DIR/argv"
      printf '%s' "$2" >"$STUB_DIR/stdout"
      printf '%s' "$3" >"$STUB_DIR/stderr"
      printf '%s' "$1" >"$STUB_DIR/exit"
    }

    # A session that carried two states and then dropped. Both lines must reach
    # the bar untouched — this script derives nothing and must rewrite nothing.
    reset 255 '{"text":"󰑓 rebuilding","tooltip":"converging now","class":"building","alt":"building"}
    {"text":"󰄬 1a2b3c4","tooltip":"converged with main","class":"current","alt":"current"}
    ' "Connection to classic-laddie closed by remote host."
    res=$(waybar-converge)

    if [ "$(printf '%s\n' "$res" | jq -sr '[.[] | .class] | join(",")')" = "building,current,unreachable,building,current,unreachable" ]; then
      ok "the far end's lines pass through in order, each drop appended as unreachable"
    else fail "the far end's lines pass through in order, each drop appended as unreachable" \
      "classes: $(printf '%s\n' "$res" | jq -sr '[.[] | .class] | join(",")')"; fi

    if [ "$(printf '%s\n' "$res" | jq -sr '.[1].tooltip')" = "converged with main" ]; then
      ok "a rendered line is emitted verbatim, tooltip included"
    else fail "a rendered line is emitted verbatim, tooltip included"; fi

    # Two invocations for two attempts: the stream reconnects rather than
    # leaving the bar frozen on whatever arrived last.
    if [ "$(wc -l <"$STUB_DIR/argv")" -eq 2 ]; then
      ok "the loop reconnects after the stream ends"
    else fail "the loop reconnects after the stream ends" "argv: $(cat "$STUB_DIR/argv")"; fi

    # The far end is asked to stream, not polled, and is told which name the
    # workstation knows it by so its tooltips say something the user recognises.
    case "$(head -n 1 "$STUB_DIR/argv")" in
      *"classic-laddie converge-status watch --host classic-laddie"*)
        ok "the remote command is a watch, labelled with the host's local name" ;;
      *) fail "the remote command is a watch, labelled with the host's local name" \
        "argv: $(head -n 1 "$STUB_DIR/argv")" ;;
    esac

    # ssh's real shape: a warning line, then the diagnostic, then a newline.
    # The last non-empty one is the one worth a tooltip.
    reset 255 "" "Warning: Permanently added 'classic-laddie' to known hosts.
    Permission denied (publickey).
    "
    res=$(waybar-converge)
    if printf '%s\n' "$res" | jq -e -s '.[0] | .class == "unreachable" and (.tooltip | contains("Permission denied"))' >/dev/null; then
      ok "ssh failure -> unreachable, quoting ssh's last diagnostic"
    else fail "ssh failure -> unreachable, quoting ssh's last diagnostic" "output: $res"; fi

    # Same, but the stream ends without a trailing newline.
    reset 255 "" "ssh: connect to host classic-laddie port 22: No route to host"
    res=$(waybar-converge)
    if printf '%s\n' "$res" | jq -e -s '.[0].tooltip | contains("No route to host")' >/dev/null; then
      ok "unterminated ssh diagnostic still reaches the tooltip"
    else fail "unterminated ssh diagnostic still reaches the tooltip" "output: $res"; fi

    # A host that closes the connection without a word still has to produce a
    # readable module rather than a truncated one.
    reset 0 "" ""
    res=$(waybar-converge)
    if printf '%s\n' "$res" | jq -e -s 'all(.class == "unreachable") and (.[0].tooltip | contains("unreachable over ssh"))' >/dev/null; then
      ok "a silent disconnect still renders unreachable"
    else fail "a silent disconnect still renders unreachable" "output: $res"; fi

    if [ "$failures" -ne 0 ]; then
      echo "$failures check(s) failed"
      exit 1
    fi
    touch $out
  ''
