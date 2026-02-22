{
  pkgs,
  lib,
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

      # Hardware Diagnostics
      smartmontools
      nvme-cli
    ];

    # Enable Flakes and new command line tools
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Increase buffer to 64MB to fix "download buffer is full" warnings
      download-buffer-size = 67108864;
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
  };
}
