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
    kitty # Terminal
    wofi # App launcher
    kdePackages.dolphin # File manager
    bibata-cursors
  ];

  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };
}
