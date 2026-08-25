# Reboot when the booted and deployed worlds have split; only when nothing that
# matters is running. A deferral is never silent — every blocked attempt is
# journaled and left in /var/lib/reboot-pending for the bar to escalate on.
#
# A host that converges continuously but never reboots keeps running the kernel
# and PID 1 it booted with while deploying new ones underneath — real update
# incompatibilities, invisible until something breaks. The detector below says
# when that has happened; the quiet-window attempt says when it is safe to fix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.autoReboot;
  scripts = import ./auto-reboot-scripts.nix { inherit pkgs; };
in
{
  options.modules.autoReboot = {
    enable = lib.mkEnableOption "Reboot into the deployed system during a quiet window once the booted one has diverged";

    attemptAt = lib.mkOption {
      type = lib.types.str;
      default = "04:45";
      description = ''
        OnCalendar expression for the daily reboot attempt. The default sits
        after the nightly backup window and before the morning.
      '';
    };

    idleMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "An interactive session idle for less than this blocks the reboot.";
    };

    blockingUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "cosmo-rebuild.service" ];
      description = "Units whose activity blocks the reboot.";
    };

    triggerAfter = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "cosmo-rebuild" ];
      description = ''
        Unit names (no `.service` suffix) after which the divergence check runs,
        so the state is accurate the moment a deploy finishes rather than up to
        an hour later. Both success and failure trigger it: a converge that ran
        several switches and then died has still moved the deployed system.
      '';
    };

    agentRunGlobs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/home/patrick/.klaus/sessions/*/runs/*.json" ];
      description = "Globs of klaus run records; a run still in flight blocks the reboot.";
    };

    agentRunMaxAgeHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 24;
      description = ''
        Run records untouched for longer than this are read as abandoned rather
        than running, so an agent that died without finalising its record cannot
        defer reboots indefinitely.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services = lib.mkMerge [
      {
        reboot-needed = {
          description = "Detect whether the booted system has diverged from the deployed one";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${scripts.reboot-needed}/bin/reboot-needed";
            # Shared with reboot-attempt below. Mode 0755 (the default) is what
            # lets the waybar poll read the state as an unprivileged user.
            StateDirectory = "reboot-pending";
            SyslogIdentifier = "reboot-needed";
          };
          path = with pkgs; [
            coreutils
            gnused
          ];
        };

        reboot-attempt = {
          description = "Reboot into the deployed system if nothing is in the way";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${scripts.reboot-attempt}/bin/reboot-attempt";
            StateDirectory = "reboot-pending";
            SyslogIdentifier = "reboot-attempt";
          };
          environment = {
            AUTO_REBOOT_IDLE_SECONDS = toString (cfg.idleMinutes * 60);
            AUTO_REBOOT_AGENT_MAX_AGE_SECONDS = toString (cfg.agentRunMaxAgeHours * 3600);
            AUTO_REBOOT_BLOCKING_UNITS = lib.concatStringsSep " " cfg.blockingUnits;
            AUTO_REBOOT_AGENT_GLOBS = lib.concatStringsSep " " cfg.agentRunGlobs;
          };
          path = with pkgs; [
            coreutils
            gawk
            gnused
            config.systemd.package
          ];
        };
      }

      (lib.genAttrs cfg.triggerAfter (_: {
        onSuccess = [ "reboot-needed.service" ];
        onFailure = [ "reboot-needed.service" ];
      }))
    ];

    systemd.timers.reboot-needed = {
      description = "Check hourly for a booted/deployed split";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnCalendar = "hourly";
        RandomizedDelaySec = "5m";
        Persistent = true;
      };
    };

    systemd.timers.reboot-attempt = {
      description = "Daily quiet-window reboot attempt";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.attemptAt;
        # Deliberately not Persistent: a missed quiet window is skipped, not
        # replayed at whatever hour the machine next comes up. Tomorrow's
        # window is soon enough, and the state file keeps the pending reboot
        # visible until one of them lands.
        Persistent = false;
        AccuracySec = "1m";
      };
    };
  };
}
