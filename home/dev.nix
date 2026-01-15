{
  config,
  pkgs,
  inputs,
  lib,
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
    jujutsu # Modern VCS (jj)

    # Age tools
    inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  programs.zsh.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake .";
  };

  # Install Gemini extensions
  home.activation.installGeminiConductor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.gemini-cli}/bin/gemini extensions list | grep -q "conductor"; then
      run ${pkgs.gemini-cli}/bin/gemini extensions install https://github.com/gemini-cli-extensions/conductor --consent --auto-update
    fi
  '';

  # Git adjustments for dev if needed (e.g. signing keys)
}
