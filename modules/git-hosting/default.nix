# Declarative bare-git hosting over SSH.
# Provides a dedicated git user (git-shell, key-only) and ensures a bare
# repository exists for every name in `repos`. Repos are only ever created,
# never deleted or overwritten — removing a name from the list leaves the
# data on disk untouched.
#
# Identity is deliberately thin: the host lives on the tailnet, so Tailscale
# ACLs plus the SSH keys in `authorizedKeys` are the whole access story.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.git-hosting;

  # Managed post-receive dispatcher. Each repo's post-receive is a symlink to
  # this script, which chains every executable dropped into the repo's
  # hooks/post-receive.d/ directory (e.g. a future replication hook).
  postReceiveDispatch = pkgs.writeShellScript "git-hosting-post-receive" ''
    # Managed by services.git-hosting — do not edit.
    # Drop executable hooks into post-receive.d/ next to this symlink.
    set -eu
    hook_dir="$(dirname "$0")/post-receive.d"
    [ -d "$hook_dir" ] || exit 0
    updates="$(cat)"
    [ -n "$updates" ] || exit 0
    for hook in "$hook_dir"/*; do
      [ -x "$hook" ] || continue
      printf '%s\n' "$updates" | "$hook" "$@"
    done
  '';
in
{
  options.services.git-hosting = {
    enable = lib.mkEnableOption "declarative bare-git repository hosting over SSH";

    user = lib.mkOption {
      type = lib.types.str;
      default = "git";
      description = "System user that owns the repositories and accepts SSH pushes.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "git";
      description = "Primary group of the git hosting user.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/srv/git";
      example = "/mnt/git";
      description = ''
        Directory holding the bare repositories, one `<name>.git` per entry
        in {option}`services.git-hosting.repos`. Also the git user's home,
        so clone URLs are relative to it (`git@host:name.git`).
      '';
    };

    repos = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[a-zA-Z0-9][a-zA-Z0-9._-]*");
      default = [ ];
      example = [ "the-valley" ];
      description = ''
        Repository names to host (without the `.git` suffix). Each becomes a
        bare repository at `<dataDir>/<name>.git`, created on activation if
        missing. Existing repositories are never touched or deleted.
      '';
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys allowed to push/fetch as the git user.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.authorizedKeys != [ ];
        message = "services.git-hosting.authorizedKeys must not be empty — the git user would be unreachable.";
      }
    ];

    users.groups.${cfg.group} = { };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      # git-shell only allows git-upload-pack/git-receive-pack/git-upload-archive;
      # interactive logins are rejected (no ~/git-shell-commands).
      shell = "${pkgs.git}/bin/git-shell";
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

    services.openssh.enable = lib.mkDefault true;

    # Belt-and-braces hardening for the git user. The trailing `Match All`
    # closes the block so it can't scope directives appended to sshd_config
    # after this snippet.
    services.openssh.extraConfig = ''
      Match User ${cfg.user}
        AllowTcpForwarding no
        AllowAgentForwarding no
        X11Forwarding no
        PermitTunnel no
      Match All
    '';

    # git-shell spawns git-receive-pack/git-upload-pack from PATH
    environment.systemPackages = [ pkgs.git ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    # Create missing bare repos and (re)wire the managed post-receive
    # dispatcher on every activation where the repo list changed.
    systemd.services.git-hosting-init = {
      description = "Initialize declarative bare git repositories";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      unitConfig.RequiresMountsFor = cfg.dataDir;
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
      };
      path = [ pkgs.git ];
      script = ''
        repos=( ${lib.escapeShellArgs cfg.repos} )
        for name in "''${repos[@]}"; do
          repo="${cfg.dataDir}/$name.git"
          # Check HEAD rather than the directory itself so a pre-existing
          # empty directory still gets initialized.
          if [ ! -e "$repo/HEAD" ]; then
            git init --bare --initial-branch=main "$repo"
          fi

          # Hook scaffolding: post-receive dispatches to post-receive.d/.
          # Only manage the hook if it is absent or already ours (a store
          # symlink) — a hand-written hook is left alone.
          mkdir -p "$repo/hooks/post-receive.d"
          hook="$repo/hooks/post-receive"
          if [ -L "$hook" ]; then
            case "$(readlink "$hook")" in
              /nix/store/*) ln -sfn ${postReceiveDispatch} "$hook" ;;
            esac
          elif [ ! -e "$hook" ]; then
            ln -s ${postReceiveDispatch} "$hook"
          fi
        done
      '';
    };
  };
}
