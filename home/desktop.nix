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
    ./zed.nix
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
    # Zed is configured declaratively in ./zed.nix

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

  # org/gnome/desktop/interface color-scheme is the GSettings key
  # xdg-desktop-portal-gtk reads and maps to the freedesktop appearance
  # color-scheme (dark) exposed to portal-aware apps (e.g. Zed).
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  xdg.configFile."electron-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=WaylandWindowDecorations
  '';

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    # Hyprland 0.55 uses hyprcursor by default, but bibata-cursors ships only an
    # XCursor theme, so Hyprland can't resolve Bibata and falls back to a generic
    # default cursor. Enabling hyprcursor here exports HYPRCURSOR_THEME/SIZE so
    # Hyprland looks for a hyprcursor theme named "Bibata-Modern-Ice" (this
    # home-manager version only sets the env vars; the theme itself is generated
    # from the XCursor theme in the xdg.dataFile entry below).
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  # bibata-cursors is XCursor-only, so convert it to hyprcursor format for
  # Hyprland 0.55 (which defaults to hyprcursor). hyprcursor-util --extract
  # decompiles the XCursor theme (needs xcur2png) and --create compiles a
  # hyprcursor theme. The manifest name is set to "Bibata-Modern-Ice" so
  # Hyprland resolves HYPRCURSOR_THEME to this theme (hyprcursor matches on the
  # manifest name or the directory stem). Installed under ~/.local/share/icons,
  # which libhyprcursor searches; the XCursor theme keeps its own dir untouched.
  xdg.dataFile."icons/Bibata-Modern-Ice-hyprcursor".source =
    pkgs.runCommand "bibata-modern-ice-hyprcursor"
      {
        nativeBuildInputs = [
          pkgs.hyprcursor
          pkgs.xcur2png
        ];
      }
      ''
        hyprcursor-util --extract ${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Ice --output .
        substituteInPlace extracted_Bibata-Modern-Ice/manifest.hl \
          --replace-fail "name = Extracted Theme" "name = Bibata-Modern-Ice"
        hyprcursor-util --create extracted_Bibata-Modern-Ice --output .
        mkdir -p "$out"
        cp -r "theme_Bibata-Modern-Ice/." "$out/"
      '';
}
