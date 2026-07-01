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

  # xdg-desktop-portal-gtk reports the color scheme to portal-aware apps
  # (e.g. Zed) from the GNOME interface GSettings key below — NOT from the
  # org/freedesktop/appearance dconf path. The freedesktop block is kept as a
  # harmless hint, but "prefer-dark" here is what the portal actually reads and
  # maps to color-scheme=1 (dark).
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

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
