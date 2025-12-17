{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Development Tools
  home.packages = with pkgs; [
    # Language Servers & Runtimes
    nixd         # Nix LSP
    python3
    nodejs    
    
    # Build Tools
    gnumake
    gcc

    # CLIs
    github-cli # GitHub CLI (gh)
    gemini-cli # Gemini CLI
  ];
  
  # Git adjustments for dev if needed (e.g. signing keys)
}
