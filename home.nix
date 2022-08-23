{ config, pkgs, doom-emacs, ... }:

{
  imports = [
     ./emacs/nixos.nix
     ./code.nix
     ./git.nix
   ];
  nixpkgs.config.allowUnfree = true;
  home.packages = [
    pkgs.adoptopenjdk-hotspot-bin-16
    pkgs.jetbrains.idea-ultimate
    pkgs.google-chrome
    pkgs.slack
    (pkgs.callPackage ./gitsign.nix {})
  ];
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
    };
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
  programs.go.enable = true;
  home.stateVersion = "21.11";
  xdg.configFile."mimeapps.list".force = true;
}
