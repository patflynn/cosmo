# Waybar module: is classic-laddie still tracking cosmo main?
#
# The host converges itself to the tip of main via the `cosmo-rebuild` unit
# (hosts/classic-laddie/default.nix), which records a rev in
# /var/lib/cosmo-rebuild/deployed-rev *only after a switch succeeds*. That
# write-on-success rule is exactly what lets a failure go unnoticed: when a run
# dies the file keeps the last good rev, so a bar that compared revs and
# nothing else would keep reporting the host as converged until main next
# moved — and if the run died resolving the remote tip (host offline, GitHub
# unreachable) main is precisely what cannot move it off that reading. Hence
# the `failed` state, which outranks the rev comparison entirely.
#
# One ssh per poll gathers every fact the states need, the remote tip included:
# the host's own reachability of GitHub is the thing that has to work for a
# converge to happen, so resolving the tip there rather than locally both keeps
# the comparison honest and keeps the poll to a single round trip.
{
  pkgs,
  host ? "classic-laddie",
  repo ? "https://github.com/patflynn/cosmo.git",
  unit ? "cosmo-rebuild.service",
}:

let
  # systemd prefixes some of its own journal lines with the unit name; the
  # filter below has to match that literally, dots and all.
  unitRe = builtins.replaceStrings [ "." ] [ "\\." ] unit;
in
pkgs.writeShellScriptBin "waybar-converge" ''
  # No `set -e`: every probe below is allowed to come back empty, and each
  # failure is turned into a state rather than a non-zero exit — waybar renders
  # nothing at all for a module that dies.
  set -uo pipefail

  jq="${pkgs.jq}/bin/jq"
  host="${host}"

  emit() {
    # emit <class> <text> <tooltip>
    "$jq" -nc --arg class "$1" --arg text "$2" --arg tooltip "$3" \
      '{ text: $text, tooltip: $tooltip, class: $class, alt: $class }'
    exit 0
  }

  # Joins its non-empty arguments with newlines, so a tooltip can list a
  # journal line or a rev that may or may not exist without growing a blank
  # line when it doesn't.
  join_lines() {
    local out="" part
    for part in "$@"; do
      [ -n "$part" ] || continue
      if [ -n "$out" ]; then
        out=$(printf '%s\n%s' "$out" "$part")
      else
        out="$part"
      fi
    done
    printf '%s' "$out"
  }

  err_file=$(${pkgs.coreutils}/bin/mktemp)
  trap 'rm -f "$err_file"' EXIT

  # `ssh` is deliberately resolved on PATH: the poll runs as the desktop user
  # and has to go through their ~/.ssh/config, known_hosts and agent. The keys
  # in secrets/keys.nix are authorized for the default user on every host
  # (modules/common/users.nix), so this works with no extra setup — and when
  # the agent is locked or the host is down the failure lands on `unreachable`.
  #
  # The remote block prints one `key=value` line per fact. Each value is
  # captured with $(...) so a probe that fails leaves an empty value instead of
  # derailing the block, and the journal line is flattened to a single line so
  # the parse below can stay line-oriented.
  #
  # The journal filter drops systemd's own framing to surface what the unit's
  # script last printed, which is what answers "failed on what?". systemd
  # writes some of those lines bare ("Finished …") and some prefixed with the
  # unit ("cosmo-rebuild.service: Consumed …"), hence the optional prefix.
  #
  # `repo` and `unit` are interpolated into the remote command unescaped. They
  # are build-time constants supplied by this repo, never runtime input, and
  # keep them that way: the block is wrapped in single quotes for the *local*
  # shell, which strips one level of quoting before ssh sends it, so
  # lib.escapeShellArg here would be consumed locally and protect nothing on
  # the far end. Anything untrusted would have to be passed as an argument to
  # the remote command rather than spliced into its text.
  response=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" '
    printf "rev=%s\n" "$(cat /var/lib/cosmo-rebuild/deployed-rev 2>/dev/null)"
    printf "tip=%s\n" "$(git ls-remote "${repo}" refs/heads/main 2>/dev/null | cut -f1)"
    printf "active=%s\n" "$(systemctl is-active ${unit} 2>/dev/null)"
    printf "failed=%s\n" "$(systemctl is-failed ${unit} 2>/dev/null)"
    printf "log=%s\n" "$(journalctl -u ${unit} -n 200 -o cat --no-pager 2>/dev/null | grep -vE "^(${unitRe}: )?(Starting|Started|Stopping|Stopped|Finished|Deactivated|Consumed|Main process exited|Failed with result|Scheduled restart|Triggering)" | tail -n 1 | tr "\n" " ")"
  ' 2>"$err_file") || {
    # Last non-empty line of ssh's own diagnostics: "Permission denied
    # (publickey).", "No route to host", and friends all land there, usually
    # under a banner or a known_hosts warning. The `|| [ -n "$line" ]` keeps
    # the final line when the stream ends without a newline — read reports EOF
    # there, and that line is the diagnostic we came for.
    ssh_error=""
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] && ssh_error="$line"
    done <"$err_file"
    emit unreachable "󰖪 ?" "$(join_lines "$host: unreachable over ssh" "$ssh_error")"
  }

  rev=""
  tip=""
  active=""
  failed=""
  log=""
  answered=0
  while IFS= read -r line; do
    case "$line" in
      rev=*) rev="''${line#rev=}" ;;
      tip=*) tip="''${line#tip=}" ;;
      active=*)
        active="''${line#active=}"
        answered=1
        ;;
      failed=*) failed="''${line#failed=}" ;;
      log=*) log="''${line#log=}" ;;
    esac
  done <<<"$response"

  # A journal line is not always a sentence — nix build output and structured
  # container logs run to hundreds of characters, and a tooltip that wide is
  # worse than no tooltip. The front of the line is the part that identifies
  # the failure.
  if [ "''${#log}" -gt 200 ]; then
    log="''${log:0:200}…"
  fi

  short_rev="''${rev:0:7}"
  deployed_line="deployed  ''${rev:-<none>}"
  main_line="main      ''${tip:-<unresolved>}"

  # We reached something, but not a host that answered the probe (truncated
  # stream, a shell that swallowed the block). Better to say we can't tell than
  # to derive a state from half a response.
  if [ "$answered" -eq 0 ]; then
    emit unreachable "󰖪 ?" "$host: unreadable response to the converge probe"
  fi

  # Precedence: rebuilding > failed > unreachable > current > stale.
  #
  # Activity first — a converge running right now is the answer regardless of
  # what the last one did. A unit that retries and keeps dying flaps between
  # activating and failed; both of those readings are true and useful, and what
  # must never win in that situation is the rev comparison, which would call
  # the host converged while it is visibly not.
  case "$active" in
    activating | active | reloading | deactivating)
      emit rebuilding "󰑓 rebuilding" \
        "$(join_lines "$host: converging now" "$deployed_line" "$main_line" "$log")"
      ;;
  esac

  # The state the rev comparison cannot see: the unit's last run died, so
  # deployed-rev is frozen at the last rev that switched cleanly and the host
  # has stopped following main until someone intervenes.
  if [ "$failed" = "failed" ]; then
    emit failed "󰀦 ''${short_rev:-none}" \
      "$(join_lines "$host: ${unit} FAILED — no longer tracking main" \
        "$deployed_line" "$main_line" "''${log:-(no journal output)}")"
  fi

  # Nothing running, nothing failed, but a side of the comparison is missing:
  # either nothing has ever deployed here, or the host could not resolve the
  # tip. Neither is current and neither is stale.
  if [ -z "$rev" ] || [ -z "$tip" ]; then
    emit unreachable "󰖪 ?" \
      "$(join_lines "$host: cannot compare against main" "$deployed_line" "$main_line")"
  fi

  if [ "$rev" = "$tip" ]; then
    emit current "󰄬 $short_rev" "$(join_lines "$host: converged with main" "$deployed_line")"
  fi

  emit stale "󰚰 $short_rev" \
    "$(join_lines "$host: behind main" "$deployed_line" "$main_line" \
      "Converge runs hourly; the next run will switch.")"
''
