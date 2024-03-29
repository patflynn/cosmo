{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [ emacs-all-the-icons-fonts ispell ];

  programs.doom-emacs = {
    enable = true;
    doomPrivateDir = ./doom.d;

#(import ./doom.d) {
#      inherit lib;
#      inherit (pkgs) stdenv emacs;
#    };

    emacsPackagesOverlay = self: super: {
      # fixes https://github.com/vlaci/nix-doom-emacs/issues/394
      gitignore-mode = pkgs.emacsPackages.git-modes;
      gitconfig-mode = pkgs.emacsPackages.git-modes;
    };
  };

  home.file."bin/ec" = {
    text = ''
      #!/bin/sh
      emacsclient -t $@
    '';
    executable = true;
  };
}
