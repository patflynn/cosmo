# PLACEHOLDER - This file will be regenerated during NixOS installation
#
# Run: nixos-generate-config --root /mnt
# Then copy the generated file here.
#
# Expected contents after installation:
# - LUKS device configuration for cryptroot
# - Btrfs subvolume mounts (@root, @home, @nix, @swap)
# - EFI boot partition mount
# - Swap file configuration
# - CPU microcode (AMD)
# - Kernel modules for NVMe, NVIDIA, etc.

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

  # Kernel modules
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # LUKS encryption - UPDATE THIS UUID after running cryptsetup luksFormat
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-UUID";
    allowDiscards = true; # Enable TRIM for SSD
  };

  # Btrfs subvolume mounts - UPDATE UUIDs after creating filesystem
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@root"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@swap"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-EFI-UUID";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # Swap file on Btrfs
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

  # AMD CPU
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
