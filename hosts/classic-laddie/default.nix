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

  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

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
    owner = config.cosmo.user.default; # Needs to be readable by the user running podman (or root if system)
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
    extraUpFlags = [ "--advertise-exit-node" ];
  };

  # Set your time zone
  time.timeZone = "America/New_York";

  # AUTO-LOGIN: Facilitates headless streaming via Sunshine
  services.displayManager.autoLogin = {
    enable = true;
    user = config.cosmo.user.default;
  };

  # Enable hardware acceleration for Sunshine
  services.sunshine.package = pkgs.sunshine.override { cudaSupport = true; };

  # Virtualization Host Role
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
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

  # ---------------------------------------------------------------------------
  # PXE Boot Server (TFTP)
  # ---------------------------------------------------------------------------
  # Serves netboot.xyz for network installations
  # Router config: Settings -> Networks -> Network Boot -> Server: 192.168.1.28, Filename: netboot.xyz.efi
  systemd.services.tftpd = {
    description = "TFTP Server for PXE Boot";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.atftp}/bin/atftpd --daemon --no-fork --logfile /var/log/atftpd.log /srv/tftp";
      Restart = "on-failure";
    };
  };

  # Open TFTP port
  networking.firewall.allowedUDPPorts = [ 69 ];

  # Enable SSH so you can access the server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      MaxAuthTries = 3;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      PermitTunnel = false;
    };
  };

  # Define the media group for the service stack
  users.groups.media.gid = 991; # Explicit GID for stable container references

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
    "d /mnt/media/movies    0775 ${config.cosmo.user.default} media   -   -"
    "d /mnt/media/tv        0775 ${config.cosmo.user.default} media   -   -"
    "d /mnt/media/music     0775 ${config.cosmo.user.default} media   -   -"
    "d /mnt/personal/photos 0750 ${config.cosmo.user.default} family -   -"
    "d /mnt/personal/videos 0750 ${config.cosmo.user.default} family -   -"
    # PXE Boot directory
    "d /srv/tftp            0755 root    root    -   -"
  ];

  # Host-specific user configuration
  users.users.${config.cosmo.user.default}.extraGroups = [
    "libvirtd"
    "family"
    "media"
  ];

  # Do not change this unless you reinstall the OS
  system.stateVersion = "25.11";
}
