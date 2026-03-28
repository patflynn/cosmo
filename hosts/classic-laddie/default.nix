{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../modules/common/system.nix
    ../../modules/common/users.nix
    ../../modules/common/desktop.nix
    ../../modules/common/workstation.nix
    ../../modules/common/gaming.nix
    ../../modules/common/ddcci.nix
    ../../modules/media-server/default.nix
  ];

  cosmo.user.default = "patrick";
  cosmo.user.email = "big.pat@gmail.com";

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking.hostName = "classic-laddie";

  # Bridge network for klaus microVMs
  networking.bridges.br-klaus.interfaces = [ ];
  networking.interfaces.br-klaus.ipv4.addresses = [
    {
      address = "10.100.0.1";
      prefixLength = 24;
    }
  ];

  # NAT from br-klaus so microVMs can reach the internet
  networking.nat = {
    enable = true;
    internalInterfaces = [ "br-klaus" ];
  };

  # Dell U4025QW: scale up GTK app fonts (~140 real DPI vs 96 assumed)
  environment.sessionVariables.GDK_DPI_SCALE = "1.25";

  # ---------------------------------------------------------------------------
  # Monitor Control (DDC/CI)
  # ---------------------------------------------------------------------------
  modules.ddcci.enable = true;

  modules.gaming.enable = true;

  # Auto-login to desktop session
  services.displayManager.autoLogin = {
    enable = true;
    user = config.cosmo.user.default;
  };

  # ---------------------------------------------------------------------------
  # Media Server Configuration
  # ---------------------------------------------------------------------------
  modules.media-server.enable = true;

  # Declarative config sync for the media stack (Recyclarr + VVC rejection + Prowlarr connections).
  # Before enabling, populate the API key secrets:
  #   cd secrets && agenix -e sonarr-api-key.age   # paste the API key from Sonarr UI → Settings → General
  #   cd secrets && agenix -e radarr-api-key.age   # paste the API key from Radarr UI → Settings → General
  #   cd secrets && agenix -e prowlarr-api-key.age  # paste the API key from Prowlarr UI → Settings → General
  modules.media-server.recyclarr.enable = true;

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

  # API keys for the *arr stack (used by the media-stack-sync service)
  age.secrets."sonarr-api-key" = {
    file = ../../secrets/sonarr-api-key.age;
    mode = "0400";
  };
  age.secrets."radarr-api-key" = {
    file = ../../secrets/radarr-api-key.age;
    mode = "0400";
  };
  age.secrets."prowlarr-api-key" = {
    file = ../../secrets/prowlarr-api-key.age;
    mode = "0400";
  };

  # ---------------------------------------------------------------------------
  # Remote Access (Roadmap Phase 1)
  # ---------------------------------------------------------------------------
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-exit-node" ];
  };

  # Set your time zone
  time.timeZone = "America/New_York";

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

  # ---------------------------------------------------------------------------
  # Home Automation Server
  # ---------------------------------------------------------------------------

  # Location coordinates for Home Assistant (latitude, longitude, elevation).
  # Create with: cd secrets && agenix -e ha-location.age
  # Content format (env vars sourced at service start):
  #   HA_LATITUDE=45.5250
  #   HA_LONGITUDE=-73.5970
  #   HA_ELEVATION=52
  age.secrets."ha-location" = {
    file = ../../secrets/ha-location.age;
    owner = "hass";
    group = "hass";
    mode = "0400";
  };

  services.home-assistant = {
    enable = true;
    openFirewall = true;
    extraComponents = [
      "default_config"
      "daikin"
      "hue"
      "hunterdouglas_powerview"
      "lutron_caseta"
    ];
    config = {
      homeassistant = {
        name = "Cosmo Home";
        unit_system = "metric";
        time_zone = "America/Montreal";
      };
      http = {
        server_port = 8123;
      };
    };
  };

  # Inject location coordinates from agenix secret into HA's configuration.yaml
  # at startup, after the NixOS module generates the base config file.
  systemd.services.home-assistant.preStart = lib.mkAfter ''
    source ${config.age.secrets."ha-location".path}

    cfgFile="/var/lib/hass/configuration.yaml"

    # Convert Nix store symlink to a writable copy so we can inject secrets
    if [ -L "$cfgFile" ]; then
      cp --remove-destination "$(readlink -f "$cfgFile")" "$cfgFile"
    fi

    # Add coordinates to the homeassistant section
    ${pkgs.gnused}/bin/sed -i "/^homeassistant:/a\  elevation: $HA_ELEVATION\n  latitude: $HA_LATITUDE\n  longitude: $HA_LONGITUDE" "$cfgFile"
  '';

  # Do not change this unless you reinstall the OS
  system.stateVersion = "25.11";
}
