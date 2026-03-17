{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

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

  # Bluetooth support in initrd for LUKS decryption (Kinesis 360 Pro)
  boot.initrd.systemd.dbus.enable = true;
  boot.initrd.systemd.packages = [ pkgs.bluez ];
  boot.initrd.kernelModules = [
    "btusb"
    "bluetooth"
    "uhid"
    "hidp"
    "hid_generic"
  ];
  boot.initrd.systemd.services.bluetoothd = {
    description = "Bluetooth service (initrd)";
    wantedBy = [ "initrd.target" ];
    after = [
      "dbus.socket"
      "systemd-udev-trigger.service"
    ];
    before = [ "systemd-cryptsetup@cryptroot.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez}/libexec/bluetooth/bluetoothd -n";
      # Give the BLE keyboard time to reconnect before cryptsetup prompts
      ExecStartPost = "${pkgs.coreutils}/bin/sleep 3";
      Type = "simple";
    };
    unitConfig.DefaultDependencies = false;
  };
  # Copy pairing keys into initrd.
  # N.B. These end up unencrypted on the EFI partition – accepted tradeoff so the
  # Kinesis 360 Pro BLE keyboard is available at the LUKS passphrase prompt.
  boot.initrd.secrets = {
    "/var/lib/bluetooth" = "/var/lib/bluetooth";
  };
  # Experimental BLE support in initrd
  boot.initrd.systemd.contents."/etc/bluetooth/main.conf".text = ''
    [General]
    Experimental = true
    [Policy]
    AutoEnable = true
  '';

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

  # Bluetooth settings are now in modules/common/bluetooth.nix (via desktop.nix)
  hardware.enableRedistributableFirmware = true;
}
