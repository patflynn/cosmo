{ ... }:

{
  programs.zed-editor = {
    enable = true;

    # Auto-installed on first launch. catppuccin resolves the theme below;
    # nix/toml add language support.
    extensions = [
      "catppuccin"
      "nix"
      "toml"
    ];

    userSettings = {
      theme = "Catppuccin Mocha"; # matches kitty/gtk/fuzzel Catppuccin Mocha

      # Vim mode with learning-friendly aids (Emacs user picking up vim).
      # Relative line numbers make vim motion counts easy to read off.
      vim_mode = true;
      relative_line_numbers = true;

      # Editor defaults. JetBrainsMono Nerd Font is installed system-wide via
      # home/waybar.nix (nerd-fonts.jetbrains-mono).
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size = 14;
      format_on_save = "on";
      tab_size = 2;
      minimap = {
        show = "never";
      };

      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      git = {
        inline_blame = {
          enabled = true;
        };
      };

      # Use the already-installed nixd (home/dev.nix) as the Nix LSP and
      # nixfmt (the flake formatter) for formatting.
      lsp = {
        nix = {
          binary = {
            path_lookup = true;
          };
        };
      };
      languages = {
        Nix = {
          language_servers = [ "nixd" ];
          formatter = {
            external = {
              command = "nixfmt";
            };
          };
        };
      };

      # AI: this runs on the user's Claude Pro/Max *subscription*, not a
      # pay-per-token console API key. Zed 1.8 ships first-class built-in
      # Claude Code support (agent id "claude-acp", sourced from the ACP
      # registry): it auto-detects the `claude` binary on PATH — provided
      # here by home/dev.nix (pkgs.claude-code) and already logged in via
      # OAuth — so no `language_models.anthropic` API-key config or
      # `default_model` is needed. Open the agent panel, pick "Claude Code"
      # from the New Thread menu, and it uses the CLI's subscription login.
    };
  };
}
