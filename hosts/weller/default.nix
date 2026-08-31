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
    ../../modules/common/peripherals.nix
    ../../modules/common/desktop.nix
    ../../modules/common/gaming.nix
    inputs.github-relay.nixosModules.default
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

  # ---------------------------------------------------------------------------
  # Gaming
  # ---------------------------------------------------------------------------
  modules.gaming.enable = true;

  # ---------------------------------------------------------------------------
  # GitHub Relay (webhook forwarder → klaus)
  # ---------------------------------------------------------------------------
  # klaus runs on this host and needs webhook-driven pipeline events. It listens
  # on 127.0.0.1:9800; the funnel exposes the relay at
  # https://weller.coin-inconnu.ts.net for GitHub to deliver to.
  services.github-relay = {
    enable = true;
    port = 8077;
    webhookSecretFile = config.age.secrets.github-webhook-secret.path;
    funnel.enable = true;

    consumers = {
      # Forward PR/CI events to klaus
      klaus = {
        repo = "*";
        events = [
          "push"
          "check_run"
          "check_suite"
          "pull_request"
          "pull_request_review"
        ];
        action = "http";
        url = "http://127.0.0.1:9800/webhook/github";
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Secrets
  # ---------------------------------------------------------------------------
  # World-readable because the relay runs under systemd's DynamicUser: its UID
  # is allocated at start, so the secret can't be chowned to it. Mirrors
  # classic-laddie. Tighten to 0440 if the relay ever gets a static user.
  age.secrets."github-webhook-secret" = {
    file = ../../secrets/github-webhook-secret.age;
    mode = "0444";
  };

  # ---------------------------------------------------------------------------
  # Security
  # ---------------------------------------------------------------------------
  security.sudo.wheelNeedsPassword = true;

  # Do not change this unless you reinstall the OS
  # Fresh install on the 2026 rebuild; matches the release the flake tracks.
  system.stateVersion = "26.11";
}
