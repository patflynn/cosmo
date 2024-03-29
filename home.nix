{ config, pkgs, doom-emacs, ... }:

let
  unstable = import <nixos-unstable> { config.allowUnfree = true; };
in
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
    # go-tuf
    unstable.google-chrome
    #firefox
    unstable.google-cloud-sdk
    gitAndTools.gh
    slack
    qemu
    tree
    pavucontrol
    unstable.kind
    alacritty
    step-cli
    maim
    skopeo
    xclip
    i3lock-color
    pmutils
    openssl
    killall
    gcc
    gnumake
    tmux
    dive
    trivy
    pkg-config
    jq
    python3
    fulcio
    (callPackage ./gitsign.nix {})
    cosign
    crane
    buildpack
    nodePackages.snyk
  ];

  programs.bash = {
    enable = true;
    sessionVariables = { PATH = "$HOME/bin:$PATH"; };
  };

  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --flake ~/hack/cosmo --upgrade --impure";
      ed = "emacsclient -t $1";
      idea = "idea-ultimate $1";
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
  programs.tmux = {
    enable = true;
    prefix = "C-q";
    extraConfig = ''
      set-option -g status-style fg=white,bg=colour23
      setw -g mouse on
      set -g base-index 1
      set -g history-limit 100000
      set-window-option -g mode-keys emacs
      unbind-key C-b
    '';
  };
  home.stateVersion = "21.11";
  xdg.configFile."mimeapps.list".force = true;
}
