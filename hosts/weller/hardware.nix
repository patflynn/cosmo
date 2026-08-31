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
