# Converge a host to the tip of cosmo main, continuously and on its own.
#
# Level-triggered convergence, not edge-triggered dispatch: a run converges
# the machine to whatever the remote tip is *now*, instead of treating each
# webhook as "do one rebuild". Edge-triggering lost events in practice: a
# push landing while a rebuild ran made the relay's re-dispatch block on the
# active unit (`systemctl start` waits for oneshot units) until the relay's
# exec timeout killed it, leaving main ahead of the deployed system with
# nothing scheduled to reconcile. With the loop in ./scripts.nix a lost start
# signal costs nothing — the running unit re-checks the tip after each switch,
# and the hourly timer bounds any remaining gap.
#
# The loop is also the only thing that knows what the machine is doing, so it
# is what says so: every transition is written to /var/lib/cosmo-rebuild/status
# by `converge-status set`, and the waybar widget is a projection of that file
# rather than an outside reconstruction of it. That is why nothing on the
# widget's path talks to GitHub — the one ls-remote per run *is* the machine's
# knowledge of where main is, and `phase=failed` carrying a target the host is
# not on is how "behind" reaches the bar.
#
# The unit always runs `nixos-rebuild switch`. A `boot` operation (stage the
# generation, activate at reboot, the way system.autoUpgrade does it) was
# considered and deliberately cut: it needs new phases in
# pkgs/converge-status/render.go for "deployed but not yet running" and has no
# consumer — every host that converges today switches live. Its absence is a
# decision, not an oversight.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.converge;
  converge-status = pkgs.callPackage ../../pkgs/converge-status { };
  scripts = import ./scripts.nix { inherit pkgs converge-status; };
in
{
  options.modules.converge = {
    enable = lib.mkEnableOption "Hourly convergence of this host to the tip of cosmo main";

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:patflynn/cosmo";
      description = "Flake reference the converge run builds from.";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/patflynn/cosmo.git";
      description = ''
        Git remote the run resolves refs/heads/main against. It has to name the
        same tree as `flake`: the rev this resolves is the rev recorded as
        deployed after the switch.
      '';
    };

    attr = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "nixosConfigurations attribute this host switches to.";
    };

    webhookDispatch = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Start a converge run the moment main moves, via a
          `services.github-relay` consumer. The hourly timer stays on either
          way — this only shortens the gap. Requires the relay to be enabled on
          this host.
        '';
      };

      repo = lib.mkOption {
        type = lib.types.str;
        default = "patflynn/cosmo";
        description = "owner/name the relay matches push events against.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # The one behaviour this module takes away. modules/common/system.nix turns
      # system.autoUpgrade on for every host — a nightly rebuild staged to boot.
      # A converging host would run both: two rebuild paths racing the same
      # flake, one live and one staged, with only the converge loop reporting
      # what it did. This supersedes it; modules/common/auto-reboot.nix is what
      # closes the booted-vs-deployed split that autoUpgrade's `boot` operation
      # used to cover.
      system.autoUpgrade.enable = lib.mkForce false;

      environment.systemPackages = [ converge-status ];

      systemd.services.cosmo-rebuild = {
        description = "Converge NixOS to the tip of cosmo main";
        # The switch this unit runs may change this very unit; without these,
        # activation would stop/restart it mid-flight, killing the rebuild it's
        # performing (same reason nixos-upgrade.service sets restartIfChanged).
        restartIfChanged = false;
        stopIfChanged = false;
        # StartLimit* are [Unit] keys; in [Service] systemd ignores them and the
        # rate limit silently never applies.
        unitConfig = {
          StartLimitIntervalSec = 300;
          StartLimitBurst = 3;
        };
        # The scripts default these to classic-laddie's values; setting them here
        # is what makes the same unit correct on any host.
        environment = {
          COSMO_REBUILD_REPO = cfg.repo;
          COSMO_REBUILD_FLAKE = cfg.flake;
          COSMO_REBUILD_ATTR = cfg.attr;
        };
        serviceConfig = {
          Type = "oneshot";
          # One run may perform several switches (the converge loop), so the
          # timeout covers the loop bound, not a single switch.
          TimeoutStartSec = 3600;
          # /var/lib/cosmo-rebuild/deployed-rev records the last rev that
          # *successfully switched*; the early exit against it makes a no-change
          # run cost one git ls-remote. The status file beside it is a projection
          # of the same loop, never a second ledger: deployed-rev stays the thing
          # the comparison reads.
          StateDirectory = "cosmo-rebuild";
          ExecStart = "${scripts.cosmo-rebuild}/bin/cosmo-rebuild";
          # The ways a run can end that leave the script no chance to say so —
          # TimeoutStartSec above, a kill, a crashed shell — all land here.
          ExecStopPost = "${scripts.cosmo-rebuild-result}/bin/cosmo-rebuild-result";
          # Build subprocesses inherit this unit's cgroup, so the caps actually
          # constrain the rebuild — unlike daemon-targeted limits, which don't
          # apply when nixos-rebuild runs the build directly in its own process
          # tree (see PR #515 follow-up).
          MemoryHigh = "80%";
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
        };
        path = with pkgs; [
          git
          nixos-rebuild
          nix
        ];
      };

      # Reconcile timer, belt-and-braces to the webhook: even if a push event is
      # lost entirely (relay down, network blip, or the small race between the
      # loop's final tip check and unit exit), the machine converges within
      # roughly an hour. The early exit in the script keeps the steady-state cost
      # at one git ls-remote per tick.
      systemd.timers.cosmo-rebuild = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
          RandomizedDelaySec = "5m";
          Persistent = true;
        };
      };
    })

    # Webhook dispatch is opt-in and additive: everything above stands on its own
    # with only the timer driving it.
    (lib.mkIf (cfg.enable && cfg.webhookDispatch.enable) {
      assertions = [
        {
          assertion = config.services.github-relay.enable;
          message = ''
            modules.converge.webhookDispatch.enable needs services.github-relay
            enabled on this host — the dispatch is a relay consumer. Enable the
            relay (and its webhook secret), or set webhookDispatch.enable = false
            to converge on the hourly timer alone.
          '';
        }
      ];

      # Rebuild NixOS when cosmo main is updated
      services.github-relay.consumers.cosmo-rebuild = {
        repo = cfg.webhookDispatch.repo;
        events = [ "push" ];
        branches = [ "main" ];
        action = "systemd";
        unit = "cosmo-rebuild";
      };

      # The relay's systemd action execs `systemctl start <unit>` as the service
      # user, which needs polkit's org.freedesktop.systemd1.manage-units. The
      # upstream module runs with DynamicUser, whose UID is allocated at service
      # start — polkit rules can't reliably match it — so pin a static system
      # user here and grant it exactly one verb on exactly one unit below. The
      # module's explicit sandboxing (ProtectSystem=strict, NoNewPrivileges, ...)
      # is unaffected.
      users.users.github-relay = {
        isSystemUser = true;
        group = "github-relay";
      };
      users.groups.github-relay = { };
      systemd.services.github-relay.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "github-relay";
        Group = "github-relay";
      };

      # Least-privilege grant for the rebuild dispatch: github-relay may start
      # cosmo-rebuild.service and nothing else. Without this, polkit denies
      # manage-units to unprivileged callers ("interactive authentication
      # required") and every push dispatch fails.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("unit") == "cosmo-rebuild.service" &&
              action.lookup("verb") == "start" &&
              subject.user == "github-relay") {
            return polkit.Result.YES;
          }
        });
      '';
    })
  ];
}
