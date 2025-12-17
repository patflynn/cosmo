# Server host configuration
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
  networking.hostName = "server";

  # Enable Tailscale
  services.tailscale.enable = true;

  # Disable sleep
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Media drives
  # Configuration is moved to hardware-configuration.nix for CI
  # This will be removed after migration is complete

  # Auto-update system
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    dates = "04:00";
    flake = "github:patflynn/cosmo";
  };

  # Server-specific packages
  environment.systemPackages = with pkgs; [
    tailscale
  ];
}
