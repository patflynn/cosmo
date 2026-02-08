{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/workstation.nix
  ];

  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

  # ---------------------------------------------------------------------------
  # Bootloader - systemd-boot
  # ---------------------------------------------------------------------------
  # Windows is on Disk 0, NixOS on Disk 1 - use UEFI boot menu (F11/F12) to switch
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---------------------------------------------------------------------------
  # Filesystem - Btrfs with LUKS encryption
  # ---------------------------------------------------------------------------
  boot.supportedFilesystems = [
    "btrfs"
    "ntfs"
  ];

  # LUKS encryption - device name will be set in hardware-configuration.nix
  # boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/XXXXXXXX";

  # Btrfs mount options are defined in hardware-configuration.nix

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostName = "weller";
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Hardware - NVIDIA RTX 4090
  # ---------------------------------------------------------------------------
  nixpkgs.config.allowUnfree = true;

  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Use proprietary driver for best compatibility
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

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
  services.sunshine.package = pkgs.sunshine.override { cudaSupport = true; };

  # ---------------------------------------------------------------------------
  # Gaming
  # ---------------------------------------------------------------------------
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Gamemode for performance optimization
  programs.gamemode.enable = true;

  # ---------------------------------------------------------------------------
  # Security
  # ---------------------------------------------------------------------------
  security.sudo.wheelNeedsPassword = true;

  # Do not change this unless you reinstall the OS
  system.stateVersion = "25.11";
}
