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
    };

    # Klaus agent orchestration config
    home.file.".klaus/config.json".text = builtins.toJSON {
      worktree_base = "/tmp/klaus-${config.home.username}-sessions";
      clone_base = "${config.home.homeDirectory}/hack";
      default_budget = "5.00";
      data_ref = "refs/klaus/data";
      default_branch = "main";
      trusted_reviewers = [ "gemini-code-assist[bot]" ];
      auto_merge_on_approval = true;
    };
  };
}
