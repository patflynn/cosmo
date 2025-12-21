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
  ];
}
