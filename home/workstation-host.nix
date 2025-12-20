{ config, pkgs, ... }:

{
  imports = [ ./workstation.nix ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#classic-laddie";
  };
}
