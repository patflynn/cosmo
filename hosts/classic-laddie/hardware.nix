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
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # Allow qemu-libvirtd to access the GPU
  users.groups.video.members = [ "qemu-libvirtd" ];
  users.groups.render.members = [ "qemu-libvirtd" ];

  # ---------------------------------------------------------------------------
  # Storage Support
  # ---------------------------------------------------------------------------
  boot.supportedFilesystems = [ "zfs" ];

  # ---------------------------------------------------------------------------
  # USB stability
  # ---------------------------------------------------------------------------
  # Disable USB autosuspend to prevent enumeration timeouts during boot
  # (usb 6-3.1.1: device not accepting address, error -62) and Bluetooth
  # adapter power-management stalls that cause mouse stuttering.
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

}
