{ config, pkgs, inputs, ... }:

{
  imports = [
    # No hardware-configuration.nix needed for WSL
    ../../modules/common/system.nix
  ];

  wsl = {
    enable = true;
    defaultUser = "patrick";
    startMenuLaunchers = true;
  };

  # Enable Nix Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Set default shell to zsh system-wide (optional, but good practice if HM configures it)
  programs.zsh.enable = true;
  users.users.patrick.shell = pkgs.zsh;

  system.stateVersion = "24.11"; 
}
