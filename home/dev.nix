{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  options.cosmo.gemini.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the public gemini-cli package.";
  };

  config = {
    # Development Tools
    home.packages =
      with pkgs;
      [
        # Language Servers & Runtimes
        nixd # Nix LSP
        python3
        nodejs

        # Build Tools
        gnumake
        gcc
        openssl

        # IDEs
        antigravity

        # CLIs
        claude-code # Anthropic's CLI
        github-cli # GitHub CLI (gh)
        jujutsu # Modern VCS (jj)

        # Age tools
        inputs.agenix.packages."${pkgs.stdenv.hostPlatform.system}".default

        # Agent orchestration
        inputs.klaus.packages."${pkgs.stdenv.hostPlatform.system}".default
      ]
      ++ lib.optional config.cosmo.gemini.enable pkgs.gemini-cli;

    programs.zsh.shellAliases = {
      rebuild = "if [ -e /etc/NIXOS ]; then sudo nixos-rebuild switch --flake .; else nix run home-manager -- switch --flake .; fi";
      rebuild-dev = "if [ -e /etc/NIXOS ]; then sudo nixos-rebuild switch --flake . --override-input klaus path:$HOME/hack/klaus; else nix run home-manager -- switch --flake . --override-input klaus path:$HOME/hack/klaus; fi";
    };
  };
}
