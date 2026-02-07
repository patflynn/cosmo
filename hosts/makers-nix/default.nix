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

  wsl = {
    enable = true;
    defaultUser = "patrick";
    startMenuLaunchers = true;
  };

  # Not really used but needed for host authentication for age
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      MaxAuthTries = 3;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      PermitTunnel = false;
    };
  };

  system.stateVersion = "25.11";
}
