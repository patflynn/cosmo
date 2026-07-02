{ ... }:

{
  programs.zed-editor = {
    enable = true;

    # Auto-installed on first launch. nix/toml add language support.
    # The Ayu and One theme families are bundled with Zed, so no theme
    # extension is needed for the theme below.
    extensions = [
      "nix"
      "toml"
    ];

    userSettings = {
      # Claude Code is registered as an ACP agent server ("claude-acp",
      # sourced from the registry). It runs on the user's Claude
      # subscription via the `claude` CLI (home/dev.nix), not a
      # pay-per-token API key.
      agent_servers = {
        claude-acp = {
          type = "registry";
        };
      };

      # Always use the dark theme (Ayu Dark), regardless of the system's
      # light/dark setting. The `light`/`dark` keys name the theme for each
      # mode; `mode = "dark"` pins the active one. Both themes are bundled
      # with Zed (no extension needed).
      theme = {
        mode = "dark";
        light = "One Light";
        dark = "Ayu Dark";
      };

      # JetBrains-style keybindings (muscle memory from IntelliJ/PyCharm).
      base_keymap = "JetBrains";

      # Vim mode with learning-friendly aids (Emacs user picking up vim).
      # Relative line numbers make vim motion counts easy to read off.
      vim_mode = true;
      relative_line_numbers = true;

      # Editor defaults. JetBrainsMono Nerd Font is installed system-wide via
      # home/waybar.nix (nerd-fonts.jetbrains-mono).
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_size = 15;
      ui_font_size = 16;
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
    };
  };
}
