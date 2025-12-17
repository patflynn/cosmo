# Mock hardware configuration for WSL2
# Replace with your actual WSL2 hardware configuration when deploying
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # WSL2 doesn't need traditional filesystem mounts
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  # No swap needed for WSL2
  swapDevices = [ ];

  # Disable these for WSL2
  boot.loader.grub.enable = false;

  # Basic networking
  networking.useDHCP = lib.mkDefault true;
}
