{ config, pkgs, ... }:

let
  keys = import ../../secrets/keys.nix;
in
{
  programs.zsh.enable = true;

  age.secrets.user-password.file = ../../secrets/user-password.age;

  # cause that's how I roll! (for now)
  users.mutableUsers = false;

  users.users.patrick = {
    isNormalUser = true;
    shell = pkgs.zsh;
    # Enabled systemd user instance to persist (fixes WSL2 update error)
    linger = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    hashedPasswordFile = config.age.secrets.user-password.path;

    openssh.authorizedKeys.keys = keys.users;
  };
}
