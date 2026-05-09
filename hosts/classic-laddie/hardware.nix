{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ---------------------------------------------------------------------------
  # Bootloader
  # ---------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostId = "8425e349"; # Required for ZFS
  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Hardware - NVIDIA
  # ---------------------------------------------------------------------------
  nixpkgs.config.allowUnfree = true;
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Force-load NVIDIA display modules in initrd so the GPU drives the
  # framebuffer from boot. Without this, hardware.nvidia.modesetting.enable
  # wasn't enough on driver 595.58.03 + linux-zen 6.19.12 — the kernel
  # command line set nvidia-drm.modeset=1 but nothing actually loaded
  # nvidia_drm, leaving Hyprland stuck on EFI fb at 1024x768.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Allow qemu-libvirtd to access the GPU
  users.groups.video.members = [ "qemu-libvirtd" ];
  users.groups.render.members = [ "qemu-libvirtd" ];

  # ---------------------------------------------------------------------------
  # Storage Support
  # ---------------------------------------------------------------------------
  boot.supportedFilesystems = [ "zfs" ];

  # TEMPORARY UNBLOCK: ZFS 2.4.1 in current nixpkgs is marked broken against
  # the linux-zen kernel we run (see modules/common/gaming.nix). Both
  # `pkgs.zfs` (= zfs_2_4) and `pkgs.zfs_unstable` cap at
  # kernelMaxSupportedMajorMinor = "6.19", and our zen kernel is past that,
  # so switching packages doesn't help — the broken check fires on both.
  # Tracked upstream: https://github.com/NixOS/nixpkgs/issues/510485
  # Remove once nixpkgs ships a ZFS release that supports the running kernel.
  nixpkgs.config.problems.handlers.zfs.broken = "warn";

  # ---------------------------------------------------------------------------
  # USB stability
  # ---------------------------------------------------------------------------
  # Disable USB autosuspend to prevent enumeration timeouts during boot
  # (usb 6-3.1.1: device not accepting address, error -62) and Bluetooth
  # adapter power-management stalls that cause mouse stuttering.
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

}
