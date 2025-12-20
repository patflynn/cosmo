{ config, pkgs, ... }:

{
  imports = [ ./dev.nix ];

  # Workstation specific home-manager config (e.g. specialized aliases)
  programs.zsh.shellAliases = {
    # Add any workstation-specific aliases here
  };
}
