{ config, pkgs, doom-emacs, ... }:

{
  imports = [
     ./emacs/nixos.nix
   ];
  home.stateVersion = "21.11";
  xdg.configFile."mimeapps.list".force = true;
}