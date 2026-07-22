{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  options.cosmo.antigravity.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether to install the native (non-FHS) Antigravity IDE
      (pkgs.antigravity, autoPatchelf-based) and the antigravity CLI
      (pkgs.antigravity-cli). Unfree; requires
      nixpkgs.config.allowUnfree on the host.
    '';
  };

  options.cosmo.klaus.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to enable the klaus multi-agent orchestrator and its dependencies (like claude-code).
    '';
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

  options.cosmo.standaloneHomeManager.autoUpgrade = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to install a systemd *user* timer that rebuilds this standalone
        home-manager configuration from cosmo upstream once a day. This is the
        standalone-home-manager analogue of NixOS `system.autoUpgrade`, for
        home-manager installs on non-NixOS hosts (e.g. the corp Debian box /
        Crostini) where there is no system-level rebuild.

        Do NOT enable this where NixOS `system.autoUpgrade` applies: on NixOS the
        system rebuild already manages home-manager, and a standalone
        `home-manager switch` from a user timer would create a competing,
        NixOS-unmanaged generation. (The service also hard-guards against this at
        runtime by no-opping when `/etc/NIXOS` exists.)
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

        # CLIs
        github-cli # GitHub CLI (gh)
        jujutsu # Modern VCS (jj)
        difftastic # Structural diff (difft), wired to the `git dft` alias below

        # Age tools
        inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default

        # the valley CLI (S1 integrator verbs: pending/review); ships from the engine repo
        inputs.the-valley.packages."${pkgs.stdenv.hostPlatform.system}".valley
      ]
      ++ lib.optionals config.cosmo.klaus.enable [
        claude-code # Anthropic's CLI

        # Agent orchestration (integration tests fail inside macOS build sandboxes)
        (inputs.klaus.packages."${pkgs.stdenv.hostPlatform.system}".default.overrideAttrs (oldAttrs: {
          doCheck = false;
        }))
      ]
      ++ lib.optionals config.cosmo.antigravity.enable [
        pkgs.antigravity
        pkgs.antigravity-cli
      ];

    programs.zsh.shellAliases = {
      rebuild = "if [ -e /etc/NIXOS ]; then sudo nixos-rebuild switch --flake .; else nix run home-manager -- switch --flake .; fi";
    };

    # Delta as git's pager for diff/log/show (home-manager's first-class
    # module; programs.git.delta was renamed to programs.delta upstream).
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true; # n/N jump between files in a diff
        line-numbers = true;
      };
    };

    # Structural second-opinion diff: `git dft` runs difftastic on demand
    # without making it the default differ.
    programs.git.settings.alias.dft = "-c diff.external=difft diff";

    # Klaus agent orchestration config
    home.file.".klaus/config.json" = lib.mkIf config.cosmo.klaus.enable {
      text = builtins.toJSON {
        worktree_base = "/tmp/klaus-sessions";
        clone_base = "${config.home.homeDirectory}/hack";
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
    };

    # Daily standalone home-manager rebuild from cosmo upstream (the
    # standalone-home-manager analogue of NixOS `system.autoUpgrade`, for
    # non-NixOS hosts). Uses a systemd *user* timer; the rebuild pulls the latest
    # flake from GitHub (--refresh), so no local clone is required, mirroring the
    # `update` shell alias.
    systemd.user =
      lib.mkIf (pkgs.stdenv.isLinux && config.cosmo.standaloneHomeManager.autoUpgrade.enable)
        (
          let
            upgradeScript = pkgs.writeShellScript "cosmo-home-autoupgrade" ''
              set -euo pipefail

              # Belt-and-suspenders: never run on NixOS. There `system.autoUpgrade`
              # already manages home-manager; a standalone switch here would create a
              # competing, NixOS-unmanaged generation. No-op cleanly if enabled by
              # mistake.
              if [ -e /etc/NIXOS ]; then
                echo "cosmo-home-autoupgrade: running on NixOS — use system.autoUpgrade instead; skipping."
                exit 0
              fi

              # Resolve the target inside the script so $(hostname -s) is not baked
              # into the Nix store path. PATH and NIX_SSL_CERT_FILE are supplied by
              # the unit's Environment= (see below) — systemd user services do not
              # source the shell profile, so we set them declaratively rather than
              # probing for them at runtime.
              HOSTNAME=$(hostname -s)
              TARGET="${config.cosmo.standaloneHomeManager.autoUpgrade.flakeRef}#${config.home.username}@$HOSTNAME"
              echo "cosmo-home-autoupgrade: rebuilding from $TARGET"
              exec home-manager switch --no-write-lock-file --refresh --flake "$TARGET"
            '';
          in
          {
            services.cosmo-home-autoupgrade = {
              Unit.Description = "Rebuild standalone home-manager from cosmo upstream";
              Service = {
                Type = "oneshot";
                # systemd *user* services start with a minimal environment and do NOT
                # source the shell profile / /etc/profile.d/nix.sh, so the Nix env the
                # installer wires into the shell is absent. Supply it declaratively:
                #   PATH               so `nix`/`home-manager` (in the user profile) resolve
                #   NIX_SSL_CERT_FILE  so client-side TLS works when fetching the flake
                #                      from GitHub (pkgs.cacert is the same CA bundle
                #                      nixpkgs uses everywhere; %h is systemd's $HOME).
                Environment = [
                  "PATH=%h/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
                  "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                ];
                ExecStart = "${upgradeScript}";
              };
            };
            timers.cosmo-home-autoupgrade = {
              Unit.Description = "Daily standalone home-manager rebuild from cosmo upstream";
              Timer = {
                OnCalendar = config.cosmo.standaloneHomeManager.autoUpgrade.onCalendar;
                Persistent = true; # catch up if the machine was off at the scheduled time
                RandomizedDelaySec = "30m";
              };
              Install.WantedBy = [ "timers.target" ];
            };
          }
        );

    # Daily standalone home-manager rebuild from cosmo upstream for macOS via Launchd.
    # Runs the rebuild automatically on a schedule, matching the Linux systemd timer behavior.
    launchd.agents.cosmo-home-autoupgrade =
      lib.mkIf (pkgs.stdenv.isDarwin && config.cosmo.standaloneHomeManager.autoUpgrade.enable)
        (
          let
            upgradeScript = pkgs.writeShellScript "cosmo-home-autoupgrade" ''
              set -euo pipefail

              # Resolve the target inside the script so $(hostname -s) is not baked
              # into the Nix store path.
              HOSTNAME=$(hostname -s)
              TARGET="${config.cosmo.standaloneHomeManager.autoUpgrade.flakeRef}#${config.home.username}@$HOSTNAME"
              echo "cosmo-home-autoupgrade: rebuilding from $TARGET"

              # Launchd agents start with a minimal environment. Set up the environment
              # variables so Nix can resolve binaries and perform secure downloads from GitHub.
              export PATH="${config.home.homeDirectory}/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
              export NIX_SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

              exec home-manager switch --no-write-lock-file --refresh --flake "$TARGET"
            '';
          in
          {
            enable = true;
            config = {
              ProgramArguments = [ "${upgradeScript}" ];
              StartCalendarInterval = [
                {
                  Hour = 10;
                  Minute = 0;
                } # Run daily at 10:00 AM
              ];
              StandardOutPath = "/tmp/cosmo-home-autoupgrade.out.log";
              StandardErrorPath = "/tmp/cosmo-home-autoupgrade.err.log";
            };
          }
        );
  };
}
