{ config, pkgs, doom-emacs, ... }:

{
  imports = [
     ./emacs/nixos.nix
     ./code.nix
   ];
  nixpkgs.config.allowUnfree = true;
  home.packages = [
    pkgs.adoptopenjdk-hotspot-bin-16
    pkgs.jetbrains.idea-ultimate
  ];
  home.stateVersion = "21.11";
  xdg.configFile."mimeapps.list".force = true;
}
