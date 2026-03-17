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
