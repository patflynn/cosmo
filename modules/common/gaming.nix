{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.gaming;
in
{
  options.modules.gaming = {
    enable = lib.mkEnableOption "Zen kernel, sched-ext, and gaming optimizations";
  };

  config = lib.mkIf cfg.enable {
    # Zen kernel: low-latency interactive scheduling tuned for desktops
    boot.kernelPackages = pkgs.linuxPackages_zen;

    # Userspace BPF CPU scheduler for low-latency frame pacing
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
    };

    # Gamescope: Valve's micro-compositor for per-game display management
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # Steam with gamescope session (the "Steam Deck" login option)
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
    };

    # Gamemode: dynamic system optimization when games are running
    programs.gamemode = {
      enable = true;
      settings = {
        general.renice = 10;
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
      };
    };

    # Stable kernel fallback — select "stable" in systemd-boot if zen has issues
    specialisation.stable-kernel.configuration = {
      system.nixos.tags = [ "stable" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
      services.scx.enable = lib.mkForce false;
    };

    # Gaming-related user groups
    users.users.${config.cosmo.user.default}.extraGroups = [
      "audio"
      "gamemode"
    ];
  };
}
