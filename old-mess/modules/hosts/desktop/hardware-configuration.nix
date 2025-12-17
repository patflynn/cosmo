# Copied from original classic-laddie/hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/0e522e40-0da0-4c88-b1ee-46072b963684";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/A18D-41E6";
      fsType = "vfat";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/9ea584ee-d806-4fae-9e9a-8067faa188b4"; }];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

# For CI Testing, uncomment this instead and comment out the above:
# { config, lib, pkgs, modulesPath, ... }:
# 
# {
#   imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
# 
#   boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
#   boot.initrd.kernelModules = [ ];
#   boot.kernelModules = [ "kvm-amd" ];
#   boot.extraModulePackages = [ ];
# 
#   fileSystems."/" = {
#     device = "none";
#     fsType = "tmpfs";
#   };
# 
#   fileSystems."/boot" = {
#     device = "none";
#     fsType = "tmpfs";
#   };
# 
#   swapDevices = [ ];
# 
#   networking.useDHCP = lib.mkDefault true;
#   hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
# }
