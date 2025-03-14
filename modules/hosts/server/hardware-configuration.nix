# Mock hardware configuration for CI testing
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  fileSystems."/boot" = {
    device = "none";
    fsType = "tmpfs";
  };

  fileSystems."/media" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "nofail" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  networking.hostId = "00000000"; # Required for ZFS
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}