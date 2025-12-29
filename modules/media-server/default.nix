{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.media-server;
in
{
  options.modules.media-server = {
    enable = lib.mkEnableOption "Media Server Stack (Plex, Arrs, Torrent/VPN)";
    vpnSecretPath = lib.mkOption {
      type = lib.types.path;
      default = "/run/agenix/media-vpn";
      description = "Path to the file containing VPN credentials (WIREGUARD_PRIVATE_KEY, WIREGUARD_ADDRESSES)";
    };
  };

  config = lib.mkIf cfg.enable {

    # ---------------------------------------------------------
    # 1. System & Hardware Tweaks
    # ---------------------------------------------------------

    # Hardware acceleration is critical for transcoding.
    # The host (classic-laddie) has an Nvidia GPU configured.
    # Plex will automatically detect NVENC if the drivers are loaded system-wide.
    hardware.graphics = {
      enable = true;
    };

    # ---------------------------------------------------------
    # 2. Permissions & Groups
    # ---------------------------------------------------------

    # Host `classic-laddie` defines the `media` group and basic mount points.

    users.users.patrick.extraGroups = [
      "media"
      "podman"
    ];

    # Allow Plex to read/write to the media directory
    users.users.plex.extraGroups = [ "media" ];

    systemd.tmpfiles.rules = [
      "d /mnt/media/downloads 0775 patrick media -"
      "d /mnt/media/downloads/usenet 0775 patrick media -"
      "d /mnt/media/downloads/usenet/incomplete 0775 patrick media -"
      "d /mnt/media/downloads/usenet/complete 0775 patrick media -"
      "d /mnt/media/downloads/usenet/complete/tv 0775 patrick media -"
      "d /mnt/media/downloads/usenet/complete/movies 0775 patrick media -"
      "d /mnt/media/downloads/torrents 0775 patrick media -"
      "d /mnt/media/downloads/torrents/incomplete 0775 patrick media -"
      "d /mnt/media/downloads/torrents/complete 0775 patrick media -"
      "d /mnt/media/downloads/torrents/complete/tv 0775 patrick media -"
      "d /mnt/media/downloads/torrents/complete/movies 0775 patrick media -"

      # App Config Directories
      "d /var/lib/gluetun 0700 root root -"
      "d /var/lib/sabnzbd 0775 patrick media -"
      "d /var/lib/sabnzbd/config 0775 patrick media -"
      "d /var/lib/qbittorrent 0775 patrick media -"
      "d /var/lib/qbittorrent/config 0775 patrick media -"
    ];

    # ---------------------------------------------------------
    # 3. Native Services (The "Arr" Stack + Plex)
    # ---------------------------------------------------------

    services.plex = {
      enable = true;
      openFirewall = true;
    };

    services.sonarr = {
      enable = true;
      group = "media";
      openFirewall = true;
    };

    services.radarr = {
      enable = true;
      group = "media";
      openFirewall = true;
    };

    services.prowlarr = {
      enable = true;
      openFirewall = true;
    };

    # SABnzbd (Moved to container for VPN)
    # services.sabnzbd removed.

    services.overseerr = {
      enable = true;
      openFirewall = true;
    };

    # Open ports for containerized services (Gluetun/SABnzbd/qBittorrent)
    # Native services open their own ports, but containers need explicit host firewall rules.
    # Also open 80/443 for Caddy reverse proxy.
    networking.firewall = {
      allowedTCPPorts = [
        80 # HTTP
        443 # HTTPS
        8080 # SABnzbd
        8081 # qBittorrent
      ];
    };

    # Allow services to talk to each other using friendly hostnames
    # e.g., Sonarr can talk to "sabnzbd" instead of "localhost"
    networking.hosts = {
      "127.0.0.1" = [
        "plex"
        "sonarr"
        "radarr"
        "prowlarr"
        "overseerr"
        "sabnzbd"
        "qbittorrent"
      ];
    };

    # ---------------------------------------------------------
    # 4. Reverse Proxy (Easy Access)
    # ---------------------------------------------------------

    # Allow family to type "http://overseerr" to get to the request portal
    # Note: Requires a Local DNS record on your router (UDM Pro) pointing "overseerr" to this host's IP.
    services.caddy = {
      enable = true;
      virtualHosts."http://overseerr" = {
        extraConfig = ''
          tls off
          reverse_proxy localhost:5055
        '';
      };
      virtualHosts."http://overseerr.local" = {
        extraConfig = ''
          tls off
          reverse_proxy localhost:5055
        '';
      };
    };

    # ---------------------------------------------------------
    # 5. Containerized Torrenting & Usenet (Gluetun VPN)
    # ---------------------------------------------------------

    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers = {

      # The VPN Gateway
      gluetun = {
        image = "qmcgaw/gluetun";
        capabilities = {
          NET_ADMIN = true;
        };
        environmentFiles = [ cfg.vpnSecretPath ];
        environment = {
          VPN_SERVICE_PROVIDER = "mullvad";
          VPN_TYPE = "wireguard";
          DNS_ADDRESS = "10.64.0.1";

          # Ports to forward from the VPN interface to the container network
          FIREWALL_VPN_INPUT_PORTS = "8081";
          FIREWALL_OUTBOUND_SUBNETS = "192.168.0.0/16"; # Allow Local LAN access
        };
        ports = [
          "8081:8081" # qBittorrent WebUI
          "8080:8080" # SABnzbd WebUI
          "6881:6881/tcp"
          "6881:6881/udp"
        ];
        volumes = [
          "/var/lib/gluetun:/gluetun"
        ];
        extraOptions = [ "--device=/dev/net/tun:/dev/net/tun" ];
      };

      # The Torrent Client (Routed through Gluetun)
      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        dependsOn = [ "gluetun" ];
        extraOptions = [ "--network=container:gluetun" ];
        environment = {
          PUID = "1000"; # patrick
          PGID = "991"; # media
          TZ = "America/New_York";
          WEBUI_PORT = "8081";
        };
        volumes = [
          "/var/lib/qbittorrent/config:/config"
          "/mnt/media/downloads/torrents:/downloads"
        ];
      };

      # The Usenet Client (Routed through Gluetun)
      sabnzbd = {
        image = "lscr.io/linuxserver/sabnzbd:latest";
        dependsOn = [ "gluetun" ];
        extraOptions = [ "--network=container:gluetun" ];
        environment = {
          PUID = "1000"; # patrick
          PGID = "991"; # media
          TZ = "America/New_York";
        };
        volumes = [
          "/var/lib/sabnzbd/config:/config"
          "/mnt/media/downloads/usenet:/downloads" # Will create 'complete' and 'incomplete' here
        ];
      };
    };
  };
}
