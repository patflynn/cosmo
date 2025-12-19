{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ ./common.nix ];

  # Development Tools
  home.packages = with pkgs; [
    # Language Servers & Runtimes
    nixd # Nix LSP
    python3
    nodejs

    # Build Tools
    gnumake
    gcc

    # CLIs
    github-cli # GitHub CLI (gh)
    gemini-cli # Gemini CLI

    # Age tools
    inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  # Git adjustments for dev if needed (e.g. signing keys)
}
