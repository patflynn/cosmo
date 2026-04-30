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
    # path leaves user sessions stuck waiting on swap-in.
    systemd.oomd = {
      enable = true;
      enableSystemSlice = true;
    };

    # Backstop: hard memory ceiling on nix-daemon so a single build can't eat
    # the whole machine during the nightly auto-upgrade window.
    systemd.services.nix-daemon.serviceConfig.MemoryHigh = lib.mkDefault "20G";
  };
}
