# Reel-life AI media chatops agent microVM module.
# Runs the reel-life Telegram bot inside a cloud-hypervisor microVM
# managed by microvm.nix on classic-laddie.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.reel-life.nixosModules.default
  ];

  # --------------------------------------------------------------------------
  # microVM settings
  # --------------------------------------------------------------------------
  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 2;
    mem = 1024;

    # Share the host /nix/store read-only via virtiofs
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
      }
    ];

    writableStoreOverlay = "/nix/.rw-store";

    # Persistent volume for bot state/notes
    volumes = [
      {
        image = "reel-life-data.img";
        mountPoint = "/var/lib/reel-life";
        size = 2048; # 2 GB
        fsType = "ext4";
      }
    ];

    # TAP network interface
    interfaces = [
      {
        type = "tap";
        id = "vm-reel-0";
        mac = "02:00:00:00:01:01";
      }
    ];
  };

  # Manually mount the host secrets share
  fileSystems."/run/secrets/host" = {
    device = "secrets";
    fsType = "virtiofs";
    options = [ "nofail" ];
  };

  # --------------------------------------------------------------------------
  # Networking
  # --------------------------------------------------------------------------
  networking = {
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = "10.100.1.2/24";
        Gateway = "10.100.1.1";
        DNS = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
  };

  # --------------------------------------------------------------------------
  # Reel-life service
  # --------------------------------------------------------------------------
  services.reel-life = {
    enable = true;
    chatBackend = "telegram";
    sonarrUrl = "http://10.100.1.1:8989";
    chatTelegramChatID = 0; # auto-capture from first message
    # Empty list permits any user to interact during initial bootstrap.
    # After setup, populate with Telegram user IDs to restrict access.
    chatTelegramAllowedUsers = [ ];
    environmentFiles = [
      "/run/secrets/host/reel-life-telegram-token"
      "/run/secrets/host/anthropic-key"
      "/run/reel-life/media.env"
    ];
    monitorEnabled = true;
    monitorInterval = "5m";
    logLevel = "info";
  };

  # Format the raw secrets into the EnvironmentFile format expected by reel-life
  # Using ExecStartPre ensures mounts (virtiofs) are ready.
  # We use a wrapper bash script to ensure path resolution.
  systemd.services.reel-life.serviceConfig.ExecStartPre = [
    (pkgs.writeShellScript "reel-life-setup-env" ''
      mkdir -p /run/reel-life
      if [ -f /run/secrets/host/sonarr-api-key ]; then
        echo "SONARR_API_KEY=$(cat /run/secrets/host/sonarr-api-key)" > /run/reel-life/media.env
        echo "RADARR_API_KEY=$(cat /run/secrets/host/radarr-api-key)" >> /run/reel-life/media.env
        chmod 0644 /run/reel-life/media.env
      fi
    '')
  ];

  # --------------------------------------------------------------------------
  # Services & packages
  # --------------------------------------------------------------------------
  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Import SSH authorized keys so we can log in
  users.users.root.openssh.authorizedKeys.keys =
    let
      keys = import ../../secrets/keys.nix;
    in
    keys.users;

  # --------------------------------------------------------------------------
  # Minimal NixOS baseline
  # --------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
