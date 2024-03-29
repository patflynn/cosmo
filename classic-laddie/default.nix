# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, doom-emacs,  ... }:

{
  imports =
    [ # Include the results of the hardware scan.

      ./hardware-configuration.nix
      ./host.nix
      ./../packages.nix
      ./../idea.nix
      ./../work.nix
    ];

  home-manager.users.patrick.imports = [ ../home.nix doom-emacs.hmModule ];
}
