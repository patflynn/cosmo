{ config, pkgs, ... }:

{
  imports = [
    ./common.nix
    ./hyprland.nix
  ];

  programs.zsh.shellAliases = {
    # System Maintenance
    update = "sudo nixos-rebuild switch --no-write-lock-file --refresh --flake github:patflynn/cosmo#classic-laddie";
  };
}
