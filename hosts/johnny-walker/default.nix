{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/guest.nix
  ];

  # VM Specs: 24GB RAM, 24 vCPUs, 100GB Disk
  # These settings apply when building a VM image for testing (nixos-rebuild build-vm)
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 24576; # 24GB
      cores = 24;
      diskSize = 102400; # 100GB
    };
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable Graphics
  hardware.graphics.enable = true;

  networking.hostName = "johnny-walker";
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Enable tailscale
  services.tailscale.enable = true;
  # Enable SSH
  services.openssh.enable = true;

  # Enable Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.11";
}
