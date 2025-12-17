{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/system.nix
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

  networking.hostName = "johnny-walker";
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Enable zsh system wide
  programs.zsh.enable = true;

  users.users.patrick = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" ];
    # Password hash shared with classic-laddie
    hashedPassword = "$6$ZtyAYsmFObdDrWxk$t/B4v4b8hHt3gSIjDiLy70fVwrzjjxC9/MRKAWuG/gQqlLZ/PVVclOR1bihX7l/RI8MLPUTS1vjV.ch8tYRb0/";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILc8u2oEFD+sn9vmX0gEbf62V4fmHGSvu10ENPkci3Yd"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHo0Oc728AfV2EMn30DhTWSqdWhmY8xR6np/qf6U7xvn cloud-ssh"
    ];
  };

  # Enable SSH
  services.openssh.enable = true;

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11"; 
}
