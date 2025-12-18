{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # No hardware-configuration.nix needed for WSL
    ../../modules/common/system.nix
    ../../modules/common/users.nix
  ];

  wsl = {
    enable = true;
    defaultUser = "patrick";
    startMenuLaunchers = true;
  };

  # Not really used but needed for host authentication for age
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  system.stateVersion = "25.11";
}
