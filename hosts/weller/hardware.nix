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
  # MSI MAG X870E Tomahawk WiFi (AM5) + Ryzen 9 9950X3D + RTX 4090.
  # The Wi-Fi 7 card is a Qualcomm WCN7850-class module (PCI 17cb:1107, driver
  # ath12k_pci); it and the RTL8126 (5GbE) are both in-tree on this kernel;
  # their firmware comes from enableRedistributableFirmware (not-detected.nix
  # above).
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

  boot.initrd = {
    availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "sd_mod"
      # The 9950X3D has an RDNA2 iGPU. Keep amdgpu in the initrd so the early
      # console renders natively when it lands on the iGPU instead of the 4090
      # (udev binds it only if the device is actually there) — the fallback
      # path if the card is pulled.
      "amdgpu"
    ];
    systemd.enable = true;
  };

  # Seagate FireCuda 510 firmware crashes with APST power saving (#263)
  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
  ];

  # ---------------------------------------------------------------------------
  # Filesystem - ZFS root, unencrypted (managed by disko)
  # ---------------------------------------------------------------------------
  boot.supportedFilesystems = [
    "zfs"
    "ntfs"
  ];

  # Explicitly opt into the safer 26.11+ default. Forced root pool import
  # masks real problems (split-brain, missed exports) and risks data loss.
  boot.zfs.forceImportRoot = false;

  # ZFS upstream caps at kernel 6.19, but modules/common/gaming.nix (imported
  # by this host) selects linux-zen, now 7.0.x — ZFS won't compile against it.
  # Pin stable until nixpkgs ships a ZFS with a higher cap. sched-ext is
  # upstream in 6.12+, so services.scx still works here.
  #
  # mkOverride 60 beats gaming.nix's default-priority assignment while still
  # losing to the mkForce in its stable-kernel specialisation.
  boot.kernelPackages = lib.mkOverride 60 pkgs.linuxPackages;

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostId = "74182f4c"; # Required for ZFS
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Bluetooth - disable the onboard radio
  # ---------------------------------------------------------------------------
  # This host has two Bluetooth controllers: the onboard one (USB 0489:e10a),
  # which is the Bluetooth half of the Qualcomm M.2 Wi-Fi combo card, and a
  # TP-Link UB500 dongle (Realtek RTL8761BU). The onboard radio is effectively
  # deaf to BLE — repeated 20-25s scans never saw a Kinesis Advantage360 Pro
  # keyboard a metre away, while the UB500 saw it at RSSI -62 and is what the
  # keyboard is bonded to. BlueZ makes the lowest-numbered controller its
  # default, so pairing attempts went to the deaf radio and looked like the
  # device simply wasn't advertising.
  #
  # Deauthorising the onboard device at the USB layer leaves the UB500 as the
  # only controller, so it is always hci0 and always BlueZ's default. Match on
  # vendor/product ID rather than the bus path or an hci index: the UB500
  # USB-resets itself under scan load and re-enumerates under a new number.
  #
  # The whole combo card is also disabled in the MSI BIOS (Wi-Fi is unused here
  # — wlp8s0 is down and the box routes over wired enp7s0). This rule is the
  # declarative belt-and-braces so a CMOS reset or BIOS update cannot silently
  # bring the deaf radio back; while the BIOS setting is active the device never
  # enumerates and the rule is a harmless no-op.
  #
  # ENV{DEVTYPE} rather than a bare DEVTYPE: systemd 261's udevadm verify
  # rejects the bare form with "Invalid key 'DEVTYPE'".
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
      ATTR{idVendor}=="0489", ATTR{idProduct}=="e10a", ATTR{authorized}="0"
  '';

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
