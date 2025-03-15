# Doom Emacs configuration
{ config, lib, pkgs, inputs ? {}, ... }:

let
  # Make inputs optional with default empty set to prevent infinite recursion
  # when the module is imported outside the context where inputs is available
  doomEmacs = inputs.doom-emacs or null;
in
{
  # Only import hmModule if doom-emacs input is available
  imports = lib.optional (doomEmacs != null) doomEmacs.hmModule;

  programs.doom-emacs = {
    enable = doomEmacs != null;
    doomPrivateDir = ./doom.d;

    # Doom configuration - only set if doom-emacs input is available
    doomPackageDir = lib.mkIf (doomEmacs != null) (
      let
        filteredPath = builtins.path {
          path = doomEmacs.packages.${pkgs.system}.default;
          name = "doom-packages";
          filter = path: type:
            # Include .git directory needed by Doom sync
            builtins.elem (baseNameOf path) [".git"];
        };
      in filteredPath
    );

    # Choose your Doom configuration style (defaults to full)
    # doomConfigDir = lib.mkIf (doomEmacs != null) doomEmacs.doomConfigurations.default;
  };

  # Install dependencies that Doom Emacs might need
  home.packages = lib.mkIf (doomEmacs != null) (with pkgs; [
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
  ]);

  # Add desktop application entry (only if doom-emacs is enabled)
  xdg.desktopEntries = lib.mkIf (doomEmacs != null) {
    doom-emacs = {
      name = "Doom Emacs";
      comment = "Edit text";
      icon = "emacs";
      exec = "emacs %F";
      categories = [ "Development" "TextEditor" ];
      mimeType = [ "text/plain" "text/x-chdr" "text/x-csrc" "text/x-c++hdr" "text/x-c++src" "text/x-java" "text/x-python" "text/x-ruby" "text/x-php" "text/x-csharp" "text/x-tex" "application/x-shellscript" "text/x-lisp" "text/x-perl" "text/x-haskell" "text/x-rust" "text/markdown" ];
    };
  };
}