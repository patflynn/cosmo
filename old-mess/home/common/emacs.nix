# Doom Emacs configuration
{ config, lib, pkgs, ... }:

{
  # Simple placeholder to be expanded once the NixOS configuration works properly
  programs.emacs = {
    enable = true;
    package = pkgs.emacs;
  };

  # Basic emacs dependencies
  home.packages = with pkgs; [
    git
    ripgrep
    fd
  ];
}
