{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
  ];

  # Bootloader (Keep what matches your hardware!)
  # If your hardware-configuration.nix says you are EFI, use systemd-boot:
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # If you are Legacy BIOS, you might need: boot.loader.grub.device = "/dev/sda";

  networking.hostName = "classic-laddie";
  networking.hostId= "8425e349"; # Required for ZFS
  networking.networkmanager.enable = true;

  # Storage Support (Roadmap Phase 1)
  boot.supportedFilesystems = [ "zfs" ];

  # Remote Access (Roadmap Phase 1)
  services.tailscale.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Virtualization Host Role
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true; # Required for virt-manager
  environment.systemPackages = with pkgs; [ virt-manager ];
  
  # Host-specific user configuration
  users.users.patrick.extraGroups = [ "libvirtd" ];


  security.sudo.wheelNeedsPassword = true;
  # Enable SSH so you can access the server
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # Enable Flakes and new command line tools
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Do not change this unless you reinstall the OS
  system.stateVersion = "25.11"; 
}
