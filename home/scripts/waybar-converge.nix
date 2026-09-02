# Waybar module: is this host (or a remote host) still tracking cosmo main?
#
# A stream, not a poll. Every state the bar shows is authored by the rebuild
# machinery itself — `converge-status set` at each transition of the
# cosmo-rebuild unit, and the reboot detector's verdicts in
# /var/lib/reboot-pending — and `converge-status watch` turns those files into
# one JSON line per change. So a push that starts a converge reaches the bar
# in the second the relay starts the unit, and a reboot clears from it in the
# second the post-boot detector run says so.
#
# In local mode (host == null), converge-status watch runs locally against the
# machine's own state files. In remote mode (host != null), it streams over ssh
# and owns exactly one thing the far end cannot know — that it is unreachable.
{
  pkgs,
  host ? null,
  converge-status ? pkgs.callPackage ../../pkgs/converge-status { },
  # A session this long counts as having worked, so a connection that lived an
  # afternoon and then dropped retries immediately rather than at the ceiling.
  backoffResetSeconds ? 60,
}:

pkgs.writeShellScriptBin "waybar-converge" (
  if host == null then
    ''
      # Local mode: converge-status watch monitors local /var/lib/cosmo-rebuild
      # and /var/lib/reboot-pending directly with fsnotify.
      set -euo pipefail

      while :; do
        ${converge-status}/bin/converge-status watch
        sleep 2
      done
    ''
  else
    ''
      # No `set -e`: a dropped ssh is the normal case this loop exists to handle,
      # and waybar renders nothing at all for a module that dies.
      set -uo pipefail

      # date/sleep/mktemp from a known closure; `ssh` is deliberately left to the
      # session's own PATH (see below), and nothing here shadows it.
      PATH="${pkgs.coreutils}/bin:$PATH"

      jq="${pkgs.jq}/bin/jq"
      host="${host}"

      # Test seams; nothing in production sets them. Attempts=0 means forever,
      # which is the only value the widget ever runs with.
      attempts="''${WAYBAR_CONVERGE_ATTEMPTS:-0}"
      min_backoff="''${WAYBAR_CONVERGE_MIN_BACKOFF:-2}"
      max_backoff="''${WAYBAR_CONVERGE_MAX_BACKOFF:-60}"

      err_file=$(mktemp)
      trap 'rm -f "$err_file"' EXIT

      n=0
      backoff="$min_backoff"
      while :; do
        n=$((n + 1))
        started=$(date +%s)

        # `ssh` is deliberately resolved on PATH: the stream runs as the desktop
        # user and has to go through their ~/.ssh/config, known_hosts and agent.
        # The keys in secrets/keys.nix are authorized for the default user on every
        # host (modules/common/users.nix), so this works with no extra setup.
        #
        # Keepalives, because the failure this must notice is a connection that
        # stopped carrying data without either end closing it — waybar would
        # otherwise keep showing whatever line arrived before the network went.
        #
        # stdout is inherited, not piped: `converge-status watch` writes one
        # unbuffered line per event and nothing in between should re-buffer it.
        # `$host` is a build-time constant from this module, never runtime input.
        ssh -o BatchMode=yes -o ConnectTimeout=5 \
          -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
          "$host" converge-status watch --host "$host" 2>"$err_file"

        # Last non-empty line of ssh's own diagnostics: "Permission denied
        # (publickey).", "No route to host", and friends all land there, usually
        # under a banner or a known_hosts warning. The `|| [ -n "$line" ]` keeps
        # the final line when the stream ends without a newline — read reports EOF
        # there, and that line is the diagnostic we came for.
        ssh_error=""
        while IFS= read -r line || [ -n "$line" ]; do
          [ -n "$line" ] && ssh_error="$line"
        done <"$err_file"
        : >"$err_file"

        tooltip="$host: unreachable over ssh"
        [ -n "$ssh_error" ] && tooltip=$(printf '%s\n%s' "$tooltip" "$ssh_error")
        "$jq" -nc --arg tooltip "$tooltip" \
          '{ text: "󰖪 ?", tooltip: $tooltip, class: "unreachable", alt: "unreachable" }'

        if [ "$attempts" -ne 0 ] && [ "$n" -ge "$attempts" ]; then
          exit 0
        fi

        if [ $(($(date +%s) - started)) -ge ${toString backoffResetSeconds} ]; then
          backoff="$min_backoff"
        fi
        sleep "$backoff"
        backoff=$((backoff * 2))
        [ "$backoff" -le "$max_backoff" ] || backoff="$max_backoff"
      done
    ''
)
