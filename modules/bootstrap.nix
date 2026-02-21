{
  config,
  pkgs,
  lib,
  ...
}:

let
  keys = import ../secrets/keys.nix;
in
{
  imports = [
    ./common/system.nix
  ];

  # Define the default user options here since we are importing system.nix
  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Mutable users for bootstrap
  users.mutableUsers = true;

  users.users.root.openssh.authorizedKeys.keys = keys.users;

  users.users.${config.cosmo.user.default} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = keys.users;
  };

  # Make it easy to assume root during bootstrap
  security.sudo.wheelNeedsPassword = false;

  # Ensure compatibility
  system.stateVersion = "25.11";
}
