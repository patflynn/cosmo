{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  # Bluetooth-in-initrd (Kinesis 360 Pro at the LUKS prompt) needs the host's
  # pairing data at /var/lib/bluetooth, which does not exist on a fresh install.
  # systemd-boot supports initrd secrets, so the tree is appended by the
  # bootloader installer rather than baked into the store — and
  # switch-to-configuration installs the bootloader *before* activation, so a
  # missing source aborts nixos-install and every later switch/boot with
  # "failed to create initrd secrets!". Hence two-step: install with this false,
  # pair the keyboard, then flip it. See docs/weller-build-2026.md.
  initrdBluetooth = false;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ---------------------------------------------------------------------------
  # Hardware (normally in hardware-configuration.nix, but disko handles mounts)
  # ---------------------------------------------------------------------------
  # MSI MAG X870E Tomahawk WiFi (AM5) + Ryzen 9 9950X3D + RTX 4090.
  # MT7925 (WiFi 7) and RTL8126 (5GbE) are both in-tree on this kernel; their
  # firmware comes from enableRedistributableFirmware (not-detected.nix above).
  boot.kernelModules = [ "kvm-amd" ];
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ---------------------------------------------------------------------------
  # Bootloader - systemd-boot
  # ---------------------------------------------------------------------------
  # Windows lives on its own NVMe with its own ESP; no chainloading. Switch OSes
  # from the BIOS boot menu (F11) or by changing boot order.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd = lib.mkMerge [
    {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usbhid"
        "sd_mod"
        # The 9950X3D has an RDNA2 iGPU. Keep amdgpu in the initrd so the LUKS
        # prompt renders natively when the console lands on the iGPU instead of
        # the 4090 (udev binds it only if the device is actually there).
        "amdgpu"
      ];
      systemd.enable = true;
    }

    # Bluetooth support in initrd for LUKS decryption (Kinesis 360 Pro)
    (lib.mkIf initrdBluetooth {
      systemd.dbus.enable = true;
      systemd.packages = [ pkgs.bluez ];
      kernelModules = [
        "btusb"
        "bluetooth"
        "uhid"
        "hidp"
        "hid_generic"
      ];
      systemd.services.bluetoothd = {
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
      # N.B. These end up unencrypted on the EFI partition – accepted tradeoff so
      # the Kinesis 360 Pro BLE keyboard is available at the LUKS passphrase prompt.
      secrets = {
        "/var/lib/bluetooth" = "/var/lib/bluetooth";
      };
      # Experimental BLE support in initrd
      systemd.contents."/etc/bluetooth/main.conf".text = ''
        [General]
        Experimental = true
        [Policy]
        AutoEnable = true
      '';
    })
  ];

  # Seagate FireCuda 510 firmware crashes with APST power saving (#263)
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
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
    open = true; # Ada; nixpkgs recommends the open modules on Turing and later
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  # NB: the open modules pull nvidia_uvm into boot.kernelModules themselves, so
  # unlike classic-laddie this host needs no explicit entry for CUDA.
}
