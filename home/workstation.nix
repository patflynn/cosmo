{
  config,
  pkgs,
  ...
}:

{
  imports = [ ./dev.nix ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .";
  };
}
