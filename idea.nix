{ config, pkgs, ... }:

let unstable = import <nixos> { config.allowUnfree = true; };
in {
  environment.systemPackages = with pkgs; [
    unstable.jetbrains.idea-ultimate
  ];
}
