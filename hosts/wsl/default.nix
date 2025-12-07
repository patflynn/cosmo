{ config, pkgs, inputs, ... }:

{
  imports = [
    # No hardware-configuration.nix needed for WSL
  ];

  wsl = {
    enable = true;
    defaultUser = "patrick";
    startMenuLaunchers = true;
  };

  # Enable Nix Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System Packages
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
  ];
  
  # Set default shell to zsh system-wide (optional, but good practice if HM configures it)
  programs.zsh.enable = true;
  users.users.patrick.shell = pkgs.zsh;

  system.stateVersion = "24.11"; 
}
