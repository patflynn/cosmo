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

  networking.hostName = "makers-nix";

  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

  wsl = {
    enable = true;
    defaultUser = config.cosmo.user.default;
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
