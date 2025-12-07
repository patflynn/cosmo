{ config, pkgs, ... }:

{
  imports = [ ./core.nix ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --no-write-lock-file --refresh --flake github:patflynn/cosmo#classic-laddie";
  };
}