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
  cosmo.user.default = lib.mkDefault "patrick";
  cosmo.user.email = lib.mkDefault "big.pat@gmail.com";

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # Only allow key-based root login
      PasswordAuthentication = false; # Disable password-based login for better security
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
    # No initial password - use SSH keys for access
    openssh.authorizedKeys.keys = keys.users;
  };

  # For bootstrap, we want a balance of security and convenience
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # Ensure compatibility
  system.stateVersion = "25.11";
}
