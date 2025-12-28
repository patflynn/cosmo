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
    vpnSecretPath = lib.mkOption {
      type = lib.types.path;
      default = "/run/agenix/media-vpn";
      description = "Path to the file containing VPN credentials (WIREGUARD_PRIVATE_KEY, WIREGUARD_ADDRESSES)";
    };
  };

  config = lib.mkIf cfg.enable {
    # ... (existing config) ...
    virtualisation.oci-containers.containers = {

      # The VPN Gateway
      gluetun = {
        image = "qmcgaw/gluetun";
        capabilities = [ "NET_ADMIN" ];
        environmentFiles = [ cfg.vpnSecretPath ];
        environment = {
          VPN_SERVICE_PROVIDER = "mullvad";
          VPN_TYPE = "wireguard";

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
