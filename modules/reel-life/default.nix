# Reel-life AI media chatops agent microVM module.
# Runs the reel-life Telegram bot inside a cloud-hypervisor microVM
# managed by microvm.nix on classic-laddie.
{
  config,
  pkgs,
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
  # Secrets (agenix)
  # --------------------------------------------------------------------------
  age.secrets."reel-life-telegram-token" = {
    file = ../../secrets/reel-life-telegram-token.age;
    owner = "reel-life";
    mode = "0400";
  };
  age.secrets."reel-life-anthropic-key" = {
    file = ../../secrets/reel-life-anthropic-key.age;
    owner = "reel-life";
    mode = "0400";
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
      config.age.secrets."reel-life-telegram-token".path
      config.age.secrets."reel-life-anthropic-key".path
    ];
    monitorEnabled = true;
    monitorInterval = "5m";
    logLevel = "info";
  };

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
