# Common user configuration shared between all NixOS systems
{ config, lib, pkgs, ... }:

{
  # Define user accounts
  users.users.patrick = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" "video" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      # Add any SSH keys here
    ];
  };

  # Enable sudo for wheel group
  security.sudo.wheelNeedsPassword = true;

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}