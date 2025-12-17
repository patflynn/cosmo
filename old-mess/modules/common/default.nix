# Common configuration shared between all NixOS systems
{ config, lib, pkgs, ... }:

{
  imports = [
    ./users.nix
  ];

  # Common system configuration
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Default system packages available on all systems
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
    tmux
  ];

  # Basic networking settings
  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
  };

  # Set your time zone
  time.timeZone = "America/New_York";

  # This value determines the NixOS release with which your system is to be compatible
  system.stateVersion = "23.11"; # Did you read the comment?
}
