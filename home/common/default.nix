# Common home-manager configuration shared between all systems
{ config, lib, pkgs, doom-emacs ? null, ... }:

{
  imports = [
    ./git.nix
    ./zsh.nix
    ./tmux.nix
    (import ./emacs.nix { inherit config lib pkgs doom-emacs; })
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