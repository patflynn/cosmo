# Doom Emacs configuration
{ config, lib, pkgs, inputs, doom-emacs, ... }:

{
  # Use nix-doom-emacs
  imports = [ inputs.doom-emacs.hmModule ];

  programs.doom-emacs = {
    enable = true;
    doomPrivateDir = ./doom.d; # We'll create this directory

    # Doom configuration
    doomPackageDir = let
      filteredPath = builtins.path {
        path = inputs.doom-emacs.packages.${pkgs.system}.default;
        name = "doom-packages";
        filter = path: type:
          # Include .git directory needed by Doom sync
          builtins.elem (baseNameOf path) [".git"];
      };
    in filteredPath;

    # Choose your Doom configuration style (defaults to full)
    # doomConfigDir = inputs.doom-emacs.doomConfigurations.default;
  };

  # Install dependencies that Doom Emacs might need
  home.packages = with pkgs; [
    # Core
    git
    ripgrep
    fd
    
    # Language servers/tools
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint
    nixfmt
    nixpkgs-fmt
    
    # Optional dependencies
    sqlite
    editorconfig-core-c
    
    # For org-mode/pdf tools
    texlive.combined.scheme-medium
    pandoc
  ];

  # Add desktop application entry
  xdg.desktopEntries.doom-emacs = {
    name = "Doom Emacs";
    comment = "Edit text";
    icon = "emacs";
    exec = "emacs %F";
    categories = [ "Development" "TextEditor" ];
    mimeType = [ "text/plain" "text/x-chdr" "text/x-csrc" "text/x-c++hdr" "text/x-c++src" "text/x-java" "text/x-python" "text/x-ruby" "text/x-php" "text/x-csharp" "text/x-tex" "application/x-shellscript" "text/x-lisp" "text/x-perl" "text/x-haskell" "text/x-rust" "text/markdown" ];
  };
}