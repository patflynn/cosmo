{
  config,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/workstation.nix
    ../../modules/common/gaming.nix
  ];

  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostName = "weller";

  # ---------------------------------------------------------------------------
  # Remote Access
  # ---------------------------------------------------------------------------
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

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

  # ---------------------------------------------------------------------------
  # Desktop Environment
  # ---------------------------------------------------------------------------
  time.timeZone = "America/New_York";

  # Auto-login for streaming via Sunshine
  services.displayManager.autoLogin = {
    enable = true;
    user = config.cosmo.user.default;
  };

  # Enable CUDA support for Sunshine
  # services.sunshine.package = pkgs.sunshine.override { cudaSupport = true; };

  # ---------------------------------------------------------------------------
  # Gaming
  # ---------------------------------------------------------------------------
  modules.gaming.enable = true;

  # ---------------------------------------------------------------------------
  # Security
  # ---------------------------------------------------------------------------
  security.sudo.wheelNeedsPassword = true;

  # Do not change this unless you reinstall the OS
  system.stateVersion = "25.11";
}
