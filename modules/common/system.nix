{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.cosmo.user.default = lib.mkOption {
    type = lib.types.str;
    description = "The default user for the system.";
  };

  options.cosmo.user.email = lib.mkOption {
    type = lib.types.str;
    description = "The default email for the system user.";
  };

  config = {
    # MemTest86+ boot entry for memory diagnostics (only on systemd-boot hosts)
    boot.loader.systemd-boot.memtest86 = lib.mkIf config.boot.loader.systemd-boot.enable {
      enable = true;
    };

    # Core System Packages
    # These are installed system-wide and available to all users (including root).
    environment.systemPackages = with pkgs; [
      # Editors
      vim
      emacs

      # Network Tools
      wget
      curl

      # System Monitor
      htop

      # Version Control
      git
    ];

    # Enable Flakes and new command line tools
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Increase buffer to 64MB to fix "download buffer is full" warnings
      download-buffer-size = 67108864;
      # Cap build parallelism so the nightly auto-upgrade can't saturate RAM
      # and wedge a live desktop session (see classic-laddie 2026-04-28 hang).
      max-jobs = lib.mkDefault 2;
      cores = lib.mkDefault 4;
    };

    # Run nix-daemon (and its build children) at SCHED_IDLE / IO class "idle"
    # so they only get CPU and disk bandwidth when nothing interactive wants
    # them. Complements the memory caps above: those bound how much; these
    # bound when. Together they make the nightly auto-upgrade essentially
    # invisible to a live desktop session.
    nix.daemonCPUSchedPolicy = lib.mkDefault "idle";
    nix.daemonIOSchedClass = lib.mkDefault "idle";

    # Automate Maintenance
    # Update the system daily from the upstream repo and clean up old generations
    system.autoUpgrade = {
      enable = true;
      flake = "github:patflynn/cosmo";
      flags = [
        "-L" # print build logs
        "--no-write-lock-file"
        "--refresh"
      ];
      dates = "02:00";
      randomizedDelaySec = "45min";
    };

    nix.gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };

    # Prefer reclaiming page cache over swapping anonymous pages; mitigates the
    # swap-thrash D-state hang seen when a heavy build runs alongside a desktop.
    boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 10;

    # Let systemd-oomd kill runaway system services before the kernel's own OOM
    # path leaves user sessions stuck waiting on swap-in. `enable` skips
    # mkDefault on purpose: nixos-wsl ships `oomd.enable = lib.mkDefault false`
    # for older WSL kernels lacking PSI, and two mkDefaults would collide.
    # Modern WSL2 kernels do support oomd, so we override to true everywhere.
    systemd.oomd = {
      enable = true;
      enableSystemSlice = lib.mkDefault true;
    };

    # Backstop: cap nix-daemon at a fraction of host RAM so a single build can't
    # eat the whole machine during the nightly auto-upgrade window. Percentage
    # keeps this portable across hosts with very different memory sizes.
    systemd.services.nix-daemon.serviceConfig.MemoryHigh = lib.mkDefault "80%";
  };
}
