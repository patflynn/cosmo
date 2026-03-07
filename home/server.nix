{ config, pkgs, ... }:

{
  imports = [
    ./dev.nix
  ];

  programs.zsh.shellAliases = {
    # System Maintenance
  };
}
