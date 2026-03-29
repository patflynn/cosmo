{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./dev.nix
    ./hyprland.nix
  ];

  # Essential workstation packages (User Level)
  home.packages = with pkgs; [
    fuzzel # App launcher
    kdePackages.dolphin # File manager
    bibata-cursors
    google-chrome
    xdg-desktop-portal-gtk # Portal backend for URL opening, file chooser, etc.

    # IDEs
    android-studio
    jetbrains.idea

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
      "inode/directory" = "org.kde.dolphin.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "text/html" = "google-chrome.desktop";
    };
  };

  dconf.settings."org/freedesktop/appearance" = {
    color-scheme = 1; # 1 = prefer dark
  };

  xdg.configFile."chrome-flags.conf".text = ''
    --ozone-platform=wayland
    --enable-features=WaylandWindowDecorations
  '';

  xdg.configFile."electron-flags.conf".text = config.xdg.configFile."chrome-flags.conf".text;

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
