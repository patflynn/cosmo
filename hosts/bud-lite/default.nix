{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.nixos-crostini.nixosModules.default
    ../../modules/common/system.nix
  ];

  networking.hostName = "bud-lite";

  # Crostini Integration
  crostini.enable = true;

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
