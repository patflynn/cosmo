# Desktop host configuration
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common
  ];

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Set hostname
  networking.hostName = "desktop";

  # Enable X11 and i3 window manager
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    windowManager.i3.enable = true;
    videoDrivers = [ "nouveau" ]; # Using nouveau for CI compatibility, replace with nvidia for real systems
  };

  # Audio configuration
  # Disable PipeWire to avoid conflicts
  services.pipewire.enable = false;
  
  # Use PulseAudio for sound
  services.pulseaudio = {
    enable = true;
    # Don't specify package to use default
  };

  # Enable touchpad support
  services.libinput.enable = true;

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Desktop-specific packages
  environment.systemPackages = with pkgs; [
    firefox
    alacritty
    i3lock-color
    rofi
    maim
    xclip
  ];
  
  # For CI testing only
  nixpkgs.config.allowUnfree = true;
}