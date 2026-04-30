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
    # Includes `cosmo-rebuild`, an interactive wrapper around `nixos-rebuild`
    # that runs the build inside a transient idle-scheduled scope so a heavy
    # rebuild can't outcompete the desktop for RAM/CPU and wedge the session
    # (sudo'd nixos-rebuild otherwise inherits the invoking shell's cgroup).
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

      # Interactive rebuild wrapper
      (writeShellScriptBin "cosmo-rebuild" ''
        exec sudo ${pkgs.systemd}/bin/systemd-run --scope --slice=cosmo-rebuild.slice \
          -p MemoryHigh=80% \
          -p CPUSchedulingPolicy=idle \
          -p IOSchedulingClass=idle \
          ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
      '')
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
      # Honored by every nix invocation regardless of whether builds run via
      # the daemon or directly in a sudo'd nixos-rebuild's own process tree.
      max-jobs = lib.mkDefault 2;
      cores = lib.mkDefault 4;
    };

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

    # Cap the nightly upgrade unit itself. `sudo nixos-rebuild` builds run in
    # the invoking user's terminal cgroup (e.g. the kitty scope), not under
    # nix-daemon, so daemon-targeted limits don't constrain them. Capping the
    # systemd unit that actually drives the rebuild does — its build
    # subprocesses inherit this cgroup.
    systemd.services.nixos-upgrade.serviceConfig = {
      MemoryHigh = lib.mkDefault "80%";
      CPUSchedulingPolicy = lib.mkDefault "idle";
      IOSchedulingClass = lib.mkDefault "idle";
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
  };
}
