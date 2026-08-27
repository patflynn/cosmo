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
      # The 9950X3D has an RDNA2 iGPU. Keep amdgpu in the initrd so the LUKS
      # prompt renders natively when the console lands on the iGPU instead of
      # the 4090 (udev binds it only if the device is actually there).
      "amdgpu"
    ];
    systemd.enable = true;
  };

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
