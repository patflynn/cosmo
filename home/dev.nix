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
    jujutsu # Modern VCS (jj)

    # Age tools
    inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  programs.zsh.shellAliases = {
    rebuild = "sudo nixos-rebuild switch --flake .";
  };

  # Install Gemini extensions
  home.activation.installGeminiConductor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Find the gemini binary. Preference: Home Manager profile, then system PATH.
    GEMINI_BIN=""
    if [ -x "${config.home.path}/bin/gemini" ]; then
      GEMINI_BIN="${config.home.path}/bin/gemini"
    elif command -v gemini >/dev/null; then
      GEMINI_BIN=$(command -v gemini)
    fi

    if [ -n "$GEMINI_BIN" ]; then
      if ! "$GEMINI_BIN" extensions list | grep -q "conductor"; then
        run "$GEMINI_BIN" extensions install https://github.com/gemini-cli-extensions/conductor --consent --auto-update
      fi
    fi
  '';

  # Git adjustments for dev if needed (e.g. signing keys)
}
