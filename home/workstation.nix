{
  config,
  pkgs,
  osConfig,
  ...
}:

{
  imports = [ ./dev.nix ];

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake .#${osConfig.networking.hostName}";
  };
}
