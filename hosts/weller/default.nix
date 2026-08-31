{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

let
  openrgbCfg = config.services.hardware.openrgb;

  # Two-subcommand wrapper over the OpenRGB CLI. It talks to the local SDK
  # server rather than the devices directly, so it needs no root. Omitting
  # --device applies to every detected device. Note the CLI exits 0 even when
  # it cannot reach the server (it silently falls back to direct access, which
  # needs root), so read its output rather than trusting the exit status.
  #
  # Direct is the one mode all four detected controllers share: the RGB Fusion 2
  # GPU (AORUS RTX 4090 MASTER) and the MSI Mystic Light controller only expose
  # Direct, while Static exists on the ENE DRAM modules alone.
  rgb = pkgs.writeShellScriptBin "rgb" ''
    set -euo pipefail

    openrgb=${lib.getExe openrgbCfg.package}
    server=127.0.0.1:${toString openrgbCfg.server.port}

    apply() {
      "$openrgb" --client "$server" --mode direct --color "$1"
    }

    case "''${1:-}" in
      off) apply 000000 ;;
      on) apply FFFFFF ;;
      *)
        echo "usage: rgb {on|off}" >&2
        exit 1
        ;;
    esac
  '';
in
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
  # RGB Lighting
  # ---------------------------------------------------------------------------
  # The X870E TOMAHAWK's Mystic Light USB controller (0db0:0076) also drives the
  # Liquid Freezer III's A-RGB via JRAINBOW, and the 4090 is reached over i2c.
  # motherboard = "amd" pulls in i2c-dev + i2c-piix4 for the AM5 SMBus; the
  # service ships the udev rules and runs the SDK server the "rgb" script uses.
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  environment.systemPackages = [ rgb ];

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
