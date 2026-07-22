{ config, pkgs, ... }:

{
  imports = [ ./dev.nix ];

  home.packages = [ pkgs.home-manager ];
}
