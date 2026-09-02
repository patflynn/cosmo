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
  # Direct, while Static exists on the ENE DRAM modules alone. None of them
  # offer a hardware rainbow, so "on" hands off to the rgb-cycle.service
  # below, which steps hue in software instead.
  rgb = pkgs.writeShellScriptBin "rgb" ''
    set -euo pipefail

    openrgb=${lib.getExe openrgbCfg.package}
    server=127.0.0.1:${toString openrgbCfg.server.port}

    apply() {
      "$openrgb" --client "$server" --mode direct --color "$1"
    }

    # OpenRGB defaults the MSI Mystic Light ARGB header zones (JARGB 1-3,
    # JRAINBOW) to 0 LEDs; a zone at size 0 silently drops color writes,
    # which kept the Liquid Freezer III Pro 420's ~48-LED chain on JRAINBOW
    # dark. Pin the resize here rather than relying on the runtime state in
    # /var/lib/OpenRGB/sizes.ors, which a wiped state dir would regress. 60
    # oversizes the chain on purpose -- extra addresses are just ignored,
    # and it covers any header the cooler might be moved to. Select the
    # device by name since its index shifts with USB detection order. These
    # calls print a spurious "neither mode nor color given" error but still
    # apply the resize, so discard their output and ignore their exit code.
    resize_zones() {
      for z in 0 1 2 3; do
        "$openrgb" --client "$server" --device "MSI MYSTIC LIGHT" --zone "$z" --size 60 \
          >/dev/null 2>&1 || true
      done
    }

    # No sudo here: a polkit rule below grants exactly rgb-cycle.service
    # start/stop to the wheel group, so the wrapper stays password-free.
    case "''${1:-}" in
      off)
        systemctl stop rgb-cycle
        apply 000000
        ;;
      on)
        resize_zones
        systemctl start rgb-cycle
        ;;
      *)
        echo "usage: rgb {on|off}" >&2
        exit 1
        ;;
    esac
  '';

  # Steps hue 2 degrees every 2s, so one lap of the spectrum takes ~6 minutes.
  # Runs as the rgb-cycle.service ExecStart below; only talks to the local
  # SDK server, so it needs no device access.
  rgbCycle = pkgs.writeShellScript "rgb-cycle" ''
    set -euo pipefail

    openrgb=${lib.getExe openrgbCfg.package}
    server=127.0.0.1:${toString openrgbCfg.server.port}

    hue=0
    while true; do
      color=$(awk -v h="$hue" 'BEGIN {
        s=1; v=1
        c=v*s; x=c*(1-((h/60)%2>1 ? (h/60)%2-1 : 1-(h/60)%2)); m=v-c
        if (h<60)       {r=c;g=x;b=0}
        else if (h<120) {r=x;g=c;b=0}
        else if (h<180) {r=0;g=c;b=x}
        else if (h<240) {r=0;g=x;b=c}
        else if (h<300) {r=x;g=0;b=c}
        else            {r=c;g=0;b=x}
        printf "%02X%02X%02X", (r+m)*255, (g+m)*255, (b+m)*255
      }')
      "$openrgb" --client "$server" --mode direct --color "$color" >/dev/null 2>&1
      hue=$(( (hue + 2) % 360 ))
      sleep 2
    done
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
    ../../modules/converge
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
  # Auto-converge
  # ---------------------------------------------------------------------------
  modules.converge = {
    enable = true;
    webhookDispatch.enable = true;
  };

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

  # Started/stopped only by "rgb on"/"rgb off" above -- deliberately not
  # wantedBy anything, so it never runs unless asked for and doesn't survive
  # a reboot. It only ever talks to 127.0.0.1:${openrgbCfg.server.port}, so a
  # DynamicUser with no device access is sufficient.
  systemd.services.rgb-cycle = {
    description = "Software rainbow color cycle over the OpenRGB SDK";
    serviceConfig = {
      DynamicUser = true;
      ExecStart = rgbCycle;
      Restart = "on-failure";
    };
  };

  # Lets the "rgb" wrapper start/stop rgb-cycle.service without sudo. Scoped
  # to exactly this unit and these two verbs, same carve-out pattern as the
  # github-relay -> cosmo-rebuild grant in modules/converge.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "rgb-cycle.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # ---------------------------------------------------------------------------
  # Valley Attestation
  # ---------------------------------------------------------------------------
  # valley's [a]sk verb is config-less; NAME must match the registry entry for
  # this key. weller signs as its own machine attester (unlike classic-laddie's
  # "patrick"), per qinling's identity/registry.cue makers-mark pattern.
  environment.sessionVariables = {
    VALLEY_ATTEST_KEY = "/home/${config.cosmo.user.default}/.ssh/id_ed25519";
    VALLEY_ATTEST_NAME = "weller/attestations";
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
