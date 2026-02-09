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
    wofi # App launcher
    kdePackages.dolphin # File manager
    bibata-cursors
    google-chrome

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
    };
  };

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
