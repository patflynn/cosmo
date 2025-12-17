# WSL2 NixOS host configuration
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common
  ];

  # WSL-specific settings
  wsl = {
    enable = true;
    wslConf = {
      automount.root = "/mnt";
      interop.appendWindowsPath = true;
      network.generateHosts = true;
    };
    defaultUser = "patrick"; # Replace with your username
    startMenuLaunchers = true;
  };

  # Set hostname
  networking.hostName = "nixos-wsl";

  # WSL-specific packages
  environment.systemPackages = with pkgs; [
    wslu # WSL utilities
    dos2unix
    ntfs3g
  ];

  # Set up GUI support
  services.xserver = {
    enable = false; # No need for X11 server in WSL by default
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable OpenSSH daemon
  services.openssh.enable = true;

  # Enable zsh
  programs.zsh.enable = true;

  # WSL-specific optimizations
  # Reduces initial memory usage
  boot.isContainer = true;

  # Networking is handled by Windows
  networking.dhcpcd.enable = false;

  # Disable systemd services that don't work well in WSL
  systemd.services.systemd-udevd.enable = false;
  systemd.services.NetworkManager-wait-online.enable = false;
}
