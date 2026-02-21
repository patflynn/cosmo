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
}
