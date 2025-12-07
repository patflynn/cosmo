{ config, pkgs, ... }:

{
  # Shell & Tools
  home.packages = with pkgs; [
    # Core Tools
    ripgrep      # Fast grep (Essential for Doom Emacs)
    fd           # Fast find (Essential for Doom Emacs)
    jq           # JSON parser
    tree         # Directory viewer
    btop         # Fancy htop
    
    # Emacs (The Editor)
    emacs        # The editor itself
    
    # Language Servers
    nixd         # Nix LSP
    python3
    nodejs    
  ];

  
  programs.git = {
    enable = true;
    userName = "Patrick Flynn";
    userEmail = "big.pat@gmail.com"; # Update this!
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch --no-write-lock-file --refresh --flake github:patflynn/cosmo#classic-laddie";
    };
  };

  programs.starship = {
    enable = true;
    # Custom settings can go here
  };

  home.stateVersion = "25.11";
}
