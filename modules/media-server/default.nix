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
  imports = [ ./recyclarr.nix ];
  options.modules.media-server = {
    enable = lib.mkEnableOption "Media Server Stack (Plex, Jellyfin, Arrs, Torrent/VPN)";
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

    users.users.${config.cosmo.user.default}.extraGroups = [
      "media"
      "podman"
    ];

    # Allow media services to read/write to the media directory
    # render + video grants access to /dev/dri/* for NVENC hardware transcoding
    users.users.plex.extraGroups = [
      "media"
      "render"
      "video"
    ];
    users.users.jellyfin.extraGroups = [
      "media"
      "render"
      "video"
    ];
    users.users.minidlna.extraGroups = [ "media" ];

    systemd.tmpfiles.rules = [
      "d /mnt/media/downloads 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/usenet 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/usenet/incomplete 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/usenet/complete 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/usenet/complete/tv 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/usenet/complete/movies 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/torrents 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/torrents/incomplete 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/torrents/complete 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/torrents/complete/tv 0775 ${config.cosmo.user.default} media -"
      "d /mnt/media/downloads/torrents/complete/movies 0775 ${config.cosmo.user.default} media -"

      # App Config Directories
      "d /var/lib/gluetun 0700 root root -"
      "d /var/lib/sabnzbd 0775 ${config.cosmo.user.default} media -"
      "d /var/lib/sabnzbd/config 0775 ${config.cosmo.user.default} media -"
      "d /var/lib/qbittorrent 0775 ${config.cosmo.user.default} media -"
      "d /var/lib/qbittorrent/config 0775 ${config.cosmo.user.default} media -"
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

    # ---------------------------------------------------------
    # 3b. Jellyfin (Media Server - Plex alternative)
    # ---------------------------------------------------------

    services.jellyfin = {
      enable = true;
      openFirewall = true; # Opens 8096 (web UI)
    };

    # ---------------------------------------------------------
    # 3c. MiniDLNA (DLNA/UPnP for network audio: Hegel, Devialet)
    # ---------------------------------------------------------

    services.minidlna = {
      enable = true;
      openFirewall = true; # Opens 8200 (status) + 1900/UDP (SSDP discovery)
      settings = {
        friendly_name = "classic-laddie";
        media_dir = [
          "A,/mnt/media/music"
        ];
        inotify = "yes";
      };
    };

    # Open ports for containerized services (Gluetun/SABnzbd/qBittorrent)
    # Native services open their own ports, but containers need explicit host firewall rules.
    # Also open 80/443 for Caddy reverse proxy.
    networking.firewall.allowedTCPPorts = [
      80
      443
      8080
      8081
    ];

    # Allow services to talk to each other using friendly hostnames
    # e.g., Sonarr can talk to "sabnzbd" instead of "localhost"
    networking.hosts = {
      "127.0.0.1" = [
        "plex"
        "sonarr"
        "radarr"
        "prowlarr"
        "overseerr"
        "jellyfin"
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
      globalConfig = ''
        auto_https off
      '';
      virtualHosts."overseerr".extraConfig = ''
        tls internal
        reverse_proxy localhost:5055
      '';
      virtualHosts."overseerr.local".extraConfig = ''
        tls internal
        reverse_proxy localhost:5055
      '';
      virtualHosts."jellyfin".extraConfig = ''
        tls internal
        reverse_proxy localhost:8096
      '';
      virtualHosts."jellyfin.local".extraConfig = ''
        tls internal
        reverse_proxy localhost:8096
      '';
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
          NET_RAW = true;
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
          "9999:9999" # Gluetun health server
        ];
        volumes = [
          "/var/lib/gluetun:/gluetun"
        ];
        extraOptions = [
          "--device=/dev/net/tun:/dev/net/tun"
          "--health-cmd=wget -q -O /dev/null http://localhost:9999 || exit 1"
          "--health-interval=30s"
          "--health-retries=3"
          "--health-start-period=60s"
          "--health-timeout=10s"
        ];
      };

      # The Torrent Client (Routed through Gluetun)
      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        dependsOn = [ "gluetun" ];
        extraOptions = [ "--network=container:gluetun" ];
        environment = {
          PUID = "1000"; # ${config.cosmo.user.default}
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
          PUID = "1000"; # ${config.cosmo.user.default}
          PGID = "991"; # media
          TZ = "America/New_York";
        };
        volumes = [
          "/var/lib/sabnzbd/config:/config"
          "/mnt/media/downloads/usenet:/downloads" # Will create 'complete' and 'incomplete' here
        ];
      };
    };

    # ---------------------------------------------------------
    # 6. VPN Health Monitoring & Auto-Recovery
    # ---------------------------------------------------------

    # Cascade-restart download clients when Gluetun restarts
    systemd.services.podman-qbittorrent = {
      bindsTo = [ "podman-gluetun.service" ];
      after = [ "podman-gluetun.service" ];
    };
    systemd.services.podman-sabnzbd = {
      bindsTo = [ "podman-gluetun.service" ];
      after = [ "podman-gluetun.service" ];
    };

    # Watchdog service: checks Gluetun health and restarts the VPN stack on failure
    systemd.services.vpn-watchdog = {
      description = "VPN health watchdog for Gluetun + download clients";
      path = [
        pkgs.curl
        pkgs.coreutils
        pkgs.systemd
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "vpn-watchdog" ''
          COOLDOWN_FILE="/tmp/vpn-watchdog-last-restart"
          COOLDOWN_SECONDS=300

          # Check cooldown
          if [ -f "$COOLDOWN_FILE" ]; then
            last_restart=$(cat "$COOLDOWN_FILE")
            now=$(date +%s)
            elapsed=$((now - last_restart))
            if [ "$elapsed" -lt "$COOLDOWN_SECONDS" ]; then
              echo "Cooldown active: last restart was ''${elapsed}s ago (< ''${COOLDOWN_SECONDS}s). Skipping."
              exit 0
            fi
          fi

          # Check Gluetun health endpoint
          if curl -sf --max-time 10 http://localhost:9999 > /dev/null 2>&1; then
            echo "VPN health check passed."
            exit 0
          fi

          echo "VPN health check FAILED. Restarting Gluetun stack..."
          date +%s > "$COOLDOWN_FILE"

          # Restart Gluetun first — BindsTo will cascade to qbittorrent and sabnzbd
          systemctl restart podman-gluetun.service
          echo "Gluetun stack restart triggered."
        '';
      };
    };

    systemd.timers.vpn-watchdog = {
      description = "Run VPN watchdog every 60 seconds";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "120s";
        OnUnitActiveSec = "60s";
        AccuracySec = "5s";
      };
    };
  };
}
