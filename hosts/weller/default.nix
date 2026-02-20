{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/workstation.nix
    ../../modules/common/gaming.nix
    ../../modules/common/initrd-bluetooth.nix
  ];

  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

  # ---------------------------------------------------------------------------
  # Hardware (normally in hardware-configuration.nix, but disko handles mounts)
  # ---------------------------------------------------------------------------
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ---------------------------------------------------------------------------
  # Bootloader - systemd-boot
  # ---------------------------------------------------------------------------
  # Windows is on Disk 0, NixOS on Disk 1 - use UEFI boot menu (F11/F12) to switch
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  # Seagate FireCuda 510 firmware crashes with APST power saving (#263)
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "btusb.enable_autosuspend=n"
  ];

  # ---------------------------------------------------------------------------
  # Filesystem - Btrfs with LUKS encryption (managed by disko)
  # ---------------------------------------------------------------------------
  boot.supportedFilesystems = [
    "btrfs"
    "ntfs"
  ];

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
  # Bluetooth – optimised for Kinesis Advantage 360 Pro (ZMK / BLE)
  # ---------------------------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Keep adapter in page-scan mode for instant reconnects
        FastConnectable = "true";
        # ZMK uses "Just Works" pairing – always allow re-pairing
        JustWorksRepairing = "always";
        # Better LE handling & battery reporting
        Experimental = "true";
      };
      LE = {
        # Tighter polling interval (7.5–11.25 ms) for lower input latency
        MinConnectionInterval = 6;
        MaxConnectionInterval = 9;
        ConnectionLatency = 0;
      };
      Policy = {
        AutoEnable = "true";
        ReconnectAttempts = 7;
        ReconnectIntervals = "1,2,4,8,16,32,64";
      };
    };
  };
  modules.initrd-bluetooth = {
    enable = true;
    pairingDir = ./bluetooth;
  };

  environment.systemPackages = with pkgs; [ bluetuith ];

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
