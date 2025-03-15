# Linux-specific home-manager configuration
{ config, lib, pkgs, ... }:

{
  imports = [
    ../common
    ./i3.nix
    ./alacritty.nix
  ];

  # Linux-specific packages
  home.packages = with pkgs; [
    pavucontrol
    xclip
    rofi
    i3lock-color
    maim
    firefox
  ];

  # XDG configuration
  xdg = {
    enable = true;
    userDirs.enable = true;
    mimeApps.enable = true;
  };

  # Configure fonts
  fonts.fontconfig.enable = true;
}