# Git configuration for NixOS
{ config, lib, pkgs, ... }:

{
  # This is adapted from the original git.nix in the repository root
  environment.systemPackages = with pkgs; [
    (pkgs.callPackage ../../pkgs/gitsign.nix {})
  ];
}