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
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "image/gif" = "mpv.desktop";
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

  xdg.configFile."electron-flags.conf".text =
    config.xdg.configFile."chrome-flags.conf".text;

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
