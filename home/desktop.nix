{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./dev.nix
    ./hyprland.nix
  ];

  # Essential desktop packages (User Level)
  home.packages = with pkgs; [
    fuzzel # App launcher
    thunar # File manager
    tumbler # Thumbnail service for Thunar
    ffmpegthumbnailer # Video thumbnails
    bibata-cursors
    google-chrome
    inputs.zen-browser.packages.x86_64-linux.default
    xdg-desktop-portal-gtk # Portal backend for URL opening, file chooser, etc.

    # IDEs
    android-studio
    jetbrains.idea # Unified IntelliJ IDEA distribution (Ultimate)
    # Zed is installed declaratively via programs.zed-editor below.

    # Media
    mpv # Video player
    vlc
    ffmpeg
    gthumb # Photo browser

    # File Managers
    yazi # Terminal file manager
  ];

  # --- Theming ---
  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Standard-Blue-Dark";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        tweaks = [
          "rimless"
          "black"
        ];
        variant = "mocha";
      };
    };
    gtk4.theme = null; # GTK4 apps use libadwaita; don't inherit the GTK3 theme
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # --- Programs ---
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha"; # Built-in to Nix Home Manager's Kitty module
    settings = {
      font_size = 12;
      window_padding_width = 4;
      open_url_with = "xdg-open";
      confirm_os_window_close = 0;
    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "monospace:size=12";
        terminal = "kitty -e";
      };
      colors = {
        background = "1e1e2edd";
        text = "cdd6f4ff";
        selection = "585b70ff";
        selection-text = "cdd6f4ff";
        border = "cba6f7ff";
        match = "a6e3a1ff";
        selection-match = "a6e3a1ff";
      };
      border = {
        width = 2;
        radius = 10;
      };
    };
  };

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

      # AI assistant (agent panel) wired to Anthropic Claude. The Anthropic API
      # key is NOT set here — the Nix store is world-readable. Zed reads it from
      # the ANTHROPIC_API_KEY environment variable, or you sign in through Zed's
      # UI at runtime.
      language_models = {
        anthropic = {
          version = "1";
          available_models = [
            {
              name = "claude-opus-4-8";
              display_name = "Claude Opus 4.8";
              max_tokens = 1000000;
              max_output_tokens = 128000;
            }
            {
              name = "claude-sonnet-4-6";
              display_name = "Claude Sonnet 4.6";
              max_tokens = 1000000;
              max_output_tokens = 64000;
            }
            {
              name = "claude-haiku-4-5";
              display_name = "Claude Haiku 4.5";
              max_tokens = 200000;
              max_output_tokens = 64000;
            }
          ];
        };
      };
      agent = {
        version = "2";
        default_model = {
          provider = "anthropic";
          model = "claude-opus-4-8";
        };
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Images
      "image/jpeg" = "org.gnome.gThumb.desktop";
      "image/png" = "org.gnome.gThumb.desktop";
      "image/gif" = "org.gnome.gThumb.desktop";
      "image/webp" = "org.gnome.gThumb.desktop";
      "image/tiff" = "org.gnome.gThumb.desktop";
      "image/bmp" = "org.gnome.gThumb.desktop";
      "image/svg+xml" = "org.gnome.gThumb.desktop";
      "image/heif" = "org.gnome.gThumb.desktop";
      "image/heic" = "org.gnome.gThumb.desktop";
      "image/avif" = "org.gnome.gThumb.desktop";

      # Video
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/x-flv" = "mpv.desktop";
      "video/3gpp" = "mpv.desktop";
      "video/mp2t" = "mpv.desktop";

      # Audio
      "audio/mpeg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "audio/wav" = "mpv.desktop";
      "audio/aac" = "mpv.desktop";
      "audio/mp4" = "mpv.desktop";

      # Files & Web
      "inode/directory" = "thunar.desktop";
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "text/html" = "zen.desktop";
    };
  };

  dconf.settings."org/freedesktop/appearance" = {
    color-scheme = 1; # 1 = prefer dark
  };

  xdg.configFile."electron-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=WaylandWindowDecorations
  '';

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
