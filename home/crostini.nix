{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:

{
  imports = [ ./dev.nix ];

  # Crostini Specific Configuration
  # This profile is designed for standalone Home Manager on Debian/Crostini.

  programs.zsh.shellAliases = {
    # Override common.nix 'update' alias for Home Manager standalone
    update = lib.mkForce "home-manager switch --flake github:patflynn/cosmo#${config.home.username}@${hostName}";
    # Local rebuild for testing changes
    rebuild = lib.mkForce "home-manager switch --flake .#${config.home.username}@${hostName}";
  };
}
