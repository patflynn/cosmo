{ config, pkgs, ... }:

{
  imports = [
    # Hardware config is now handled by microvm.nix
    ../../modules/common/system.nix
    ../../modules/common/guest.nix
  ];

  # Bootloader is handled by MicroVM (direct kernel boot)
  
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
    # Use the same hashed password or SSH keys as other hosts
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
