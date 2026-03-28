# Klaus agent microVM template module.
# Provides a minimal headless NixOS environment for running klaus workers
# inside cloud-hypervisor microVMs managed by microvm.nix.
{
  pkgs,
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

  environment.systemPackages = with pkgs; [
    git
    gh
    tmux
    inputs.klaus.packages.${pkgs.system}.default
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
