{ config, pkgs, ... }:

{
  imports = [ ./core.nix ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#wsl";
  };
}