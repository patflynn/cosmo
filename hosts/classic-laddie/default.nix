{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/workstation.nix
    ../../modules/media-server/default.nix
  ];

  # ---------------------------------------------------------------------------
  # Media Server Configuration
  # ---------------------------------------------------------------------------
  modules.media-server.enable = true;

  # VPN Credentials for Gluetun (Mullvad)
  # Run: agenix -e secrets/media-vpn.age
  # Content format:
  # WIREGUARD_PRIVATE_KEY=...
  # WIREGUARD_ADDRESSES=...
  age.secrets."media-vpn" = {
    file = ../../secrets/media-vpn.age;
    owner = "patrick"; # Needs to be readable by the user running podman (or root if system)
    group = "podman";
    mode = "0440";
  };

  # Bootloader (Keep what matches your hardware!)
  # If your hardware-configuration.nix says you are EFI, use systemd-boot:
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # If you are Legacy BIOS, you might need: boot.loader.grub.device = "/dev/sda";

  # Enable proprietary software (required for Nvidia drivers)
  nixpkgs.config.allowUnfree = true;

  # Graphics
  hardware.graphics.enable = true;

  # Nvidia Driver Configuration
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

  networking.hostName = "classic-laddie";
  networking.hostId = "8425e349"; # Required for ZFS
  networking.networkmanager.enable = true;

  # Storage Support (Roadmap Phase 1)
  boot.supportedFilesystems = [ "zfs" ];

  # Remote Access (Roadmap Phase 1)
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Set your time zone
  time.timeZone = "America/New_York";

  # AUTO-LOGIN: Facilitates headless streaming via Sunshine
  services.displayManager.autoLogin = {
    enable = true;
    user = "patrick";
  };

  # Enable hardware acceleration for Sunshine
  services.sunshine.package = pkgs.sunshine.override { cudaSupport = true; };

  # Virtualization Host Role
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true; # Ensures access to all devices (optional but safer for nvidia)
      swtpm.enable = true;

      # Whitelist NVIDIA devices in the cgroup configuration
      verbatimConfig = ''
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
          "/dev/rtc","/dev/hpet", "/dev/vfio/vfio",
          "/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-modeset", "/dev/nvidia-uvm", "/dev/nvidia-uvm-tools",
          "/dev/dri/renderD128"
        ]
      '';
    };
  };

  programs.dconf.enable = true; # Required for virt-manager
  environment.systemPackages = with pkgs; [ virt-manager ];

  security.sudo.wheelNeedsPassword = true;
  # Enable SSH so you can access the server
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  # Define the media group for the service stack
  users.groups.media = { };

  # Ensure the patrick group is explicitly defined to avoid resolution errors
  users.groups.family = { };

  fileSystems."/mnt/personal" = {
    device = "tank/personal";
    fsType = "zfs";
  };

  fileSystems."/mnt/media" = {
    device = "tank/media";
    fsType = "zfs";
  };

  systemd.tmpfiles.rules = [
    # Type Path             Mode User    Group   Age Argument
    "d /mnt/media/movies    0775 patrick media   -   -"
    "d /mnt/media/tv        0775 patrick media   -   -"
    "d /mnt/media/music     0775 patrick media   -   -"
    "d /mnt/personal/photos 0750 patrick family -   -"
    "d /mnt/personal/videos 0750 patrick family -   -"
  ];

  # Host-specific user configuration
  users.users.patrick.extraGroups = [
    "libvirtd"
    "family"
    "media"
  ];

  # Do not change this unless you reinstall the OS
  system.stateVersion = "25.11";
}
