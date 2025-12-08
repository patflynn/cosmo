{ config, pkgs, ... }:

{
  imports = [
    # Hardware config is now handled by microvm.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/guest.nix
  ];

  # Bootloader is handled by MicroVM (direct kernel boot)
  
  networking.hostName = "johnny-walker";
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Enable SSH
  services.openssh.enable = true;

  system.stateVersion = "25.11"; 
}
