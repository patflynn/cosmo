{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  options.cosmo.gemini.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the public gemini-cli package.";
  };

  options.cosmo.klaus.pollFallback = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether klaus should fall back to GitHub API polling for pipeline events.
      Default false relies on the Tailscale webhook relay (classic-laddie).
      Set true on hosts that cannot reach the relay (e.g. corp machines with no
      Tailscale), otherwise the pipeline receives no events.
    '';
  };

  options.cosmo.autoUpdate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to install a systemd *user* timer that rebuilds this home-manager
        configuration from cosmo upstream once a day. This is the home-manager
        equivalent of NixOS `system.autoUpgrade`, for non-NixOS hosts (e.g. the
        corp Debian box) where there is no system-level rebuild.
      '';
    };
    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "github:patflynn/cosmo";
      description = "Flake reference to rebuild from. The home config is selected as <flakeRef>#<username>@<short-hostname>.";
    };
    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar schedule for the daily rebuild.";
    };
  };

  config = {
    # Development Tools
    home.packages =
      with pkgs;
      [
        # Language Servers & Runtimes
        nixd # Nix LSP
        python3
        nodejs

        # Build Tools
        gnumake
        gcc
        openssl

        # IDEs
        antigravity

        # CLIs
        claude-code # Anthropic's CLI
        github-cli # GitHub CLI (gh)
        jujutsu # Modern VCS (jj)

        # Age tools
        inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default

        # Agent orchestration
        inputs.klaus.packages."${pkgs.stdenv.hostPlatform.system}".default
      ]
      ++ lib.optional config.cosmo.gemini.enable pkgs.gemini-cli;

    programs.zsh.shellAliases = {
      rebuild = "if [ -e /etc/NIXOS ]; then sudo nixos-rebuild switch --flake .; else nix run home-manager -- switch --flake .; fi";
    };

    # Klaus agent orchestration config
    home.file.".klaus/config.json".text = builtins.toJSON {
      worktree_base = "/tmp/klaus-sessions";
      clone_base = "/home/${config.home.username}/hack";
      default_budget = "5.00";
      data_ref = "refs/klaus/data";
      default_branch = "main";
      trusted_reviewers = [ "gemini-code-assist[bot]" ];
      auto_merge_on_approval = true;
      webhook = {
        port = 9800;
        path = "/webhook/github";
        poll_fallback = config.cosmo.klaus.pollFallback;
        relay_url = "https://classic-laddie.coin-inconnu.ts.net";
        secret_file = "/run/agenix/github-webhook-secret";
      };
    };

    # Daily home-manager rebuild from cosmo upstream (home-manager equivalent of
    # NixOS `system.autoUpgrade`, for non-NixOS hosts). Uses a systemd *user*
    # timer; the rebuild pulls the latest flake from GitHub (--refresh), so no
    # local clone is required, mirroring the `update` shell alias.
    systemd.user = lib.mkIf config.cosmo.autoUpdate.enable (
      let
        target = "${config.cosmo.autoUpdate.flakeRef}#${config.home.username}@$(hostname -s)";
        updateScript = pkgs.writeShellScript "cosmo-autoupdate" ''
          set -euo pipefail
          # systemd user services start with a minimal PATH; make nix + the
          # home-manager wrapper (installed in the user's nix profile) reachable.
          export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:$PATH"
          echo "cosmo-autoupdate: rebuilding from ${target}"
          exec home-manager switch --no-write-lock-file --refresh --flake "${target}"
        '';
      in
      {
        services.cosmo-autoupdate = {
          Unit.Description = "Rebuild home-manager from cosmo upstream";
          Service = {
            Type = "oneshot";
            ExecStart = "${updateScript}";
          };
        };
        timers.cosmo-autoupdate = {
          Unit.Description = "Daily home-manager rebuild from cosmo upstream";
          Timer = {
            OnCalendar = config.cosmo.autoUpdate.onCalendar;
            Persistent = true; # catch up if the machine was off at the scheduled time
            RandomizedDelaySec = "30m";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      }
    );
  };
}
