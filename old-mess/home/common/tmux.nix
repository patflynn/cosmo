# Tmux configuration for home-manager
{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    prefix = "C-q";
    extraConfig = ''
      set-option -g status-style fg=white,bg=colour23
      setw -g mouse on
      set -g base-index 1
      set -g history-limit 100000
      set-window-option -g mode-keys emacs
      unbind-key C-b
    '';
    terminal = "screen-256color";
    historyLimit = 100000;
    keyMode = "emacs";
    customPaneNavigationAndResize = true;
  };
}