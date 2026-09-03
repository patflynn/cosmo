{ config, lib, ... }:
let
  workUser = {
    name = "Patrick Flynn";
    email = "paflynn@google.com";
  };
in
{
  # Corp hosts (bushmills, work crostini) can't reach the Tailscale webhook
  # relay, so klaus must poll GitHub for pipeline events instead.
  cosmo.klaus.pollFallback = true;

  # These are standalone home-manager installs on non-NixOS hosts, which have no
  # system.autoUpgrade, so use a home-manager user timer to rebuild from cosmo
  # upstream daily (keeps bushmills/work crostini current). No-ops on NixOS.
  cosmo.standaloneHomeManager.autoUpgrade.enable = true;

  programs.zsh.initContent = lib.mkBefore ''
    # Source corporate configuration if it exists (e.g. from Piper/CitC)
    if [ -f "$HOME/.corp.zsh" ]; then
      source "$HOME/.corp.zsh"
    fi

    # Fix completion for tmx2 if aliased to tmux
    if type compdef > /dev/null 2>&1; then
      compdef tmx2=tmux
    fi
  '';

  programs.zsh.shellAliases = {
    tmux = "tmx2";
  };

  programs.git.settings.user = workUser;
  programs.jujutsu.settings.user = workUser;
  programs.jujutsu.settings.signing = {
    backend = "ssh";
    key = "${config.home.homeDirectory}/.ssh/auto_init_ed25519.pub";
  };
}
