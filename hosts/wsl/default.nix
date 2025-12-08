{ config, pkgs, inputs, ... }:

{
  imports = [
    # No hardware-configuration.nix needed for WSL
    ../../modules/common/system.nix
    ../../modules/common/users.nix
  ];

  wsl = {
    enable = true;
    defaultUser = "patrick";
    startMenuLaunchers = true;
  };

  system.stateVersion = "24.11"; 
}
