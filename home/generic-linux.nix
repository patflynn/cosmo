{ config, pkgs, ... }:

{
  imports = [
    ./dev.nix
  ];

  # Enable Home Manager to work on non-NixOS Linux distributions
  targets.genericLinux.enable = true;
}
