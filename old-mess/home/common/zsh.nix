# Zsh configuration for home-manager
{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --flake ~/hack/cosmo --upgrade --impure";
      ed = "emacsclient -t $1";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
    initExtra = ''
      # Add $HOME/bin to PATH
      export PATH="$HOME/bin:$PATH"
      
      # Additional ZSH configurations
      setopt AUTO_CD
      setopt EXTENDED_HISTORY
      setopt HIST_EXPIRE_DUPS_FIRST
      setopt HIST_IGNORE_DUPS
      setopt HIST_IGNORE_SPACE
      setopt HIST_VERIFY
      setopt SHARE_HISTORY
    '';
  };
}
