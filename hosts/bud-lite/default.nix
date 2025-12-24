{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../../modules/common/system.nix
  ];

  networking.hostName = "bud-lite";

  # User Configuration (Bootstrap)
  # We are not using common/users.nix here to avoid agenix dependency on first boot
  users.mutableUsers = true;
  users.users.patrick = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
    initialPassword = "password"; # Change this after first login!
  };

  system.stateVersion = "25.11";
}
