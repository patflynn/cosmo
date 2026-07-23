{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./dev.nix ];

  home.packages = [
    pkgs.home-manager

    # JetBrainsMono Nerd Font, matching home/zed.nix (buffer_font_family) and
    # home/waybar.nix ("JetBrainsMono Nerd Font"). On darwin, home-manager's
    # targets/darwin/fonts.nix copies fonts found in home.packages into
    # ~/Library/Fonts/HomeManager as real files (macOS ignores symlinked
    # fonts), so adding the package here is all that's needed to make it
    # available to macOS apps. Do NOT also link it via home.file — that path is
    # managed by home-manager and a second mechanism would collide.
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # Standalone home-manager cannot manage the root-owned launchd nix-daemon
  # (it belongs to the Nix installer, not home-manager), but it CAN make every
  # interactive/login shell robustly re-source the Nix multi-user profile so
  # nix/home-manager stay on PATH even after a macOS update overwrites
  # /etc/zshrc (where the installer hooks nix-daemon.sh). mkOrder 400 runs this
  # before common.nix's initContent (default order 1000) and work.nix's corp
  # block (mkBefore = 500), so Nix is available for everything that follows.
  programs.zsh.initContent = lib.mkOrder 400 ''
    # Self-source the Nix multi-user profile so nix/home-manager survive macOS
    # updates that clobber /etc/zshrc. The nix-daemon itself is a launchd
    # *system* daemon owned by the Nix installer, not home-manager.
    if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
  '';
}
