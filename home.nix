{ config, pkgs, doom-emacs, ... }:

{
  imports = [
     ./emacs/nixos.nix
     ./code.nix
     ./git.nix
     ./alacritty.nix
     ./rofi.nix
   ];
  nixpkgs.config.allowUnfree = true;
  home.packages = with pkgs; [
    adoptopenjdk-hotspot-bin-16
    # jetbrains.idea-ultimate
    google-chrome
    slack
    pavucontrol
    alacritty
    step-cli
    maim
    xclip
    i3lock-color
    pmutils
    openssl
    killall
    gcc
    gnumake
    tmux
    #python310
    #python310Packages.pip
    #python310Packages.pip-tools
    (callPackage ./gitsign.nix {})
    #(callPackage ./cosign.nix {})
    cosign
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
