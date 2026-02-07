{ config, pkgs, ... }:

let
  keys = import ../../secrets/keys.nix;
in
{
  programs.zsh.enable = true;

  age.secrets.user-password.file = ../../secrets/user-password.age;

  # cause that's how I roll! (for now)
  users.mutableUsers = false;

  users.users.${config.cosmo.user.default} = {
    isNormalUser = true;
    uid = 1000; # Explicit UID for stable references across config
    shell = pkgs.zsh;
    # Enabled systemd user instance to persist (fixes WSL2 update error)
    linger = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
      "input"
    ];

    hashedPasswordFile = config.age.secrets.user-password.path;

    openssh.authorizedKeys.keys = keys.users;
  };
}
