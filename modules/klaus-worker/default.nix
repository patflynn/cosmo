# Klaus agent microVM template module.
# Provides a minimal headless NixOS environment for running klaus workers
# inside cloud-hypervisor microVMs managed by microvm.nix.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  # --------------------------------------------------------------------------
  # microVM settings
  # --------------------------------------------------------------------------
  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 4;
    mem = 4096;

    # Share the host /nix/store read-only via virtiofs
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
      }
      # Share GitHub CLI configuration from the host for authentication
      {
        tag = "gh-config";
        source = "/home/patrick/.config/gh";
        mountPoint = "/root/.config/gh";
        proto = "virtiofs";
      }
    ];

    writableStoreOverlay = "/nix/.rw-store";

    # Persistent volume for worker state
    volumes = [
      {
        image = "klaus-data.img";
        mountPoint = "/var/lib/klaus";
        size = 20480; # 20 GB
        fsType = "ext4";
      }
    ];

    # TAP network interface (id and mac parameterized by caller)
    interfaces = [
      {
        type = "tap";
        id = "vm-klaus-0";
        mac = "02:00:00:00:00:01";
      }
    ];
  };

  # Manually mount the virtiofs shares
  fileSystems."/root/.config/gh" = {
    device = "gh-config";
    fsType = "virtiofs";
    options = [ "nofail" ];
  };

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
        Address = "10.100.0.2/24";
        Gateway = "10.100.0.1";
        DNS = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
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

  environment.systemPackages = [
    pkgs.git
    pkgs.gh
    pkgs.tmux
    inputs.klaus.packages.${pkgs.system}.default

    # Helper script to load secrets into the environment
    (pkgs.writeShellScriptBin "klaus-env" ''
      # Load Anthropic API Key from shared host secret
      if [ -f /run/secrets/host/anthropic-key ]; then
        export ANTHROPIC_API_KEY=$(cat /run/secrets/host/anthropic-key)
      fi

      # Use shared gh config from host
      export GH_CONFIG_DIR="/root/.config/gh"

      # Load GitHub Token from shared host secret (optional override)
      if [ -f /run/secrets/host/github-token ]; then
        TOKEN=$(cat /run/secrets/host/github-token)
        if [ "$TOKEN" != "REPLACE_ME" ] && [ -n "$TOKEN" ]; then
          export GITHUB_TOKEN="$TOKEN"
        fi
      fi
      exec "$@"
    '')
  ];

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
