{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader (Keep what matches your hardware!)
  # If your hardware-configuration.nix says you are EFI, use systemd-boot:
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # If you are Legacy BIOS, you might need: boot.loader.grub.device = "/dev/sda";

  networking.hostName = "classic-laddie";
  networking.hostId= "8425e349";
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Essential User Setup
  users.users.patrick = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "$6$ZtyAYsmFObdDrWxk$t/B4v4b8hHt3gSIjDiLy70fVwrzjjxC9/MRKAWuG/gQqlLZ/PVVclOR1bihX7l/RI8MLPUTS1vjV.ch8tYRb0/";
    
    # You can add your SSH key here to ensure you don't get locked out
    openssh.authorizedKeys.keys = [
      # makers-mark.ubuntu
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILc8u2oEFD+sn9vmX0gEbf62V4fmHGSvu10ENPkci3Yd"
    ];
  };

  # Enable SSH so you can access the server
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true; # Set to false once keys are working
    settings.PermitRootLogin = "no";
  };

  # Basic System Packages
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
  ];

  # Enable Flakes and new command line tools
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Do not change this unless you reinstall the OS
  system.stateVersion = "23.11"; 
}
