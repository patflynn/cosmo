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
    enable = lib.mkEnableOption "Media Server Stack (Jellyfin, Arrs, Torrent/VPN)";
  };

  config = lib.mkIf cfg.enable {

    # ---------------------------------------------------------
    # 1. System & Hardware Tweaks
    # ---------------------------------------------------------

    # Hardware acceleration is critical for transcoding.
    # The host (classic-laddie) has an Nvidia GPU configured.
    # Jellyfin will automatically detect NVENC if the drivers are loaded system-wide.
    hardware.graphics = {
      enable = true;
    };

    # ---------------------------------------------------------
    # 2. Permissions & Groups
    # ---------------------------------------------------------

    # Host `classic-laddie` defines the `media` group and basic mount points.
    # We ensure specific subdirectories have the right permissions.

    users.users.patrick.extraGroups = [ "media" ];

    systemd.tmpfiles.rules = [
      "d /mnt/media/downloads 0775 patrick media -"
      "d /mnt/media/downloads/usenet 0775 sabnzbd media -"
      "d /mnt/media/downloads/torrents 0775 patrick media -"
    ];

    # ---------------------------------------------------------
    # 3. Native Services (The "Arr" Stack + Jellyfin)
    # ---------------------------------------------------------

    services.jellyfin = {
      enable = true;
      openFirewall = true;
      group = "media";
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

    services.sabnzbd = {
      enable = true;
      group = "media";
      configFile = "/var/lib/sabnzbd/sabnzbd.ini"; # Default
      # Open firewall handled manually below or via web interface setting
    };
    networking.firewall.allowedTCPPorts = [ 8080 ]; # SABnzbd default

    services.jellyseerr = {
      enable = true;
      openFirewall = true;
    };

    # ---------------------------------------------------------
    # 4. Containerized Torrenting (Gluetun VPN + qBittorrent)
    # ---------------------------------------------------------

    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers = {

      # The VPN Gateway
      gluetun = {
        image = "qmcgaw/gluetun";
        capabilities = [ "NET_ADMIN" ];
        environment = {
          # -------------------------------------------------------
          # TODO: CONFIGURE YOUR VPN PROVIDER HERE
          # See: https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers
          # -------------------------------------------------------
          VPN_SERVICE_PROVIDER = "custom"; # Change to: mulvad, pia, protonvpn, etc.
          # USER = "user";
          # PASSWORD = "password";

          # Ports to forward from the VPN interface to the container network
          FIREWALL_VPN_INPUT_PORTS = "8081";
          FIREWALL_OUTBOUND_SUBNETS = "192.168.0.0/16"; # Allow Local LAN access
        };
        ports = [
          "8081:8081" # Map qBittorrent WebUI out
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
        extraOptions = [ "--network=container:gluetun" ]; # MAGIC: Use Gluetun's network
        environment = {
          PUID = "1000"; # patrick
          PGID = "100"; # users (or media group ID)
          TZ = "America/New_York";
          WEBUI_PORT = "8081";
        };
        volumes = [
          "/var/lib/qbittorrent/config:/config"
          "/mnt/media/downloads/torrents:/downloads"
        ];
      };
    };

    # Allow podman to talk to outside world if needed (usually default is fine)
    # But ensure our user can run podman if manual intervention needed
    users.users.patrick.extraGroups = [ "podman" ];
  };
}
