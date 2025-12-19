{ config, pkgs, ... }:

{
  imports = [
    ./dev.nix
    ./hyprland.nix
  ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#johnny-walker";
  };
}
