# macOS-specific home-manager configuration
{ config, lib, pkgs, ... }:

{
  imports = [
    ../common
  ];

  # macOS-specific packages
  home.packages = with pkgs; [
    coreutils
    gnused
    gawk
  ];

  # macOS-specific aliases
  programs.zsh.shellAliases = {
    ls = "ls --color=auto";
    grep = "grep --color=auto";
  };

  # Environment variables for macOS
  home.sessionVariables = {
    EDITOR = "vim";
    LC_ALL = "en_US.UTF-8";
  };
}
