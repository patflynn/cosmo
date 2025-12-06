# Common home-manager configuration shared between all systems
{ config, lib, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./zsh.nix
    ./tmux.nix
    ./emacs.nix
  ];

  # Common packages for all environments
  home.packages = with pkgs; [
    ripgrep
    jq
    tree
    htop
    gnumake
    gcc
  ];

  # Default editor configuration
  programs.vim = {
    enable = true;
    extraConfig = ''
      syntax on
      set number
      set expandtab
      set tabstop=2
      set shiftwidth=2
    '';
  };

  # State version
  home.stateVersion = "23.11";
}