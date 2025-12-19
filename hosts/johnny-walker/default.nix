{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/guest.nix
    ../../modules/common/workstation.nix
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

  # Steam et al.
  nixpkgs.config.allowUnfree = true;
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable Graphics
  hardware.graphics.enable = true;

  networking.hostName = "johnny-walker";
  networking.networkmanager.enable = true;
  # Open specific ports for this host
  networking.firewall = {
    enable = true;
    # Example: Allow Sunshine TCP if it wasn't opened automatically
    allowedTCPPorts = [ 47998 47999 48010 ];
    allowedUDPPorts = [ 47998 47999 48000 ];
  };
  # Set your time zone
  time.timeZone = "America/New_York";

  # Ensure the user is auto-logged in so Sunshine/Hyprland starts on boot
  services.getty.autologinUser = "patrick";
  # Enable tailscale
  services.tailscale.enable = true;
  # Enable SSH
  services.openssh.enable = true;

  # Enable Flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # AUTO-LOGIN: Specific to this machine's role as a headless game console
  services.displayManager.autoLogin = {
    enable = true;
    user = "patrick";
  };

  system.stateVersion = "25.11";
}
