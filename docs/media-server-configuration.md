# Media Server Configuration Guide

This document outlines the step-by-step configuration required to get the automated media stack (Plex, *Arrs, Gluetun, SABnzbd, qBittorrent) communicating correctly on NixOS.

## 1. Prerequisites (NixOS Level)

These settings are handled by the `modules/media-server/default.nix` configuration.

*   **Firewall:**
    *   Open ports **8080** (SABnzbd) and **8081** (qBittorrent) on the host to allow LAN access to containers.
    *   Native services (Plex, Sonarr, etc.) open their ports automatically.
*   **Networking:**
    *   Map service hostnames to `127.0.0.1` in `/etc/hosts` (via `networking.hosts`) to simplify inter-service communication (e.g., `sabnzbd`, `sonarr`, `plex`).
*   **Directories:**
    *   `/mnt/media/downloads/usenet/{complete,incomplete}` (Owned by `patrick:media`)
    *   `/mnt/media/downloads/torrents/{complete,incomplete}` (Owned by `patrick:media`)
    *   `/mnt/media/{tv,movies}` (Owned by `patrick:media`)
*   **Containers:**
    *   **Gluetun:** Configured with WireGuard (Mullvad) credentials. Use specific endpoint IPs to ensure stability.
    *   **SABnzbd & qBittorrent:** Network routed through Gluetun (`--network=container:gluetun`).

## 2. Download Clients Configuration

### SABnzbd (`http://sabnzbd:8080`)
1.  **Servers:** Configure your Usenet provider (e.g., UsenetServer) with SSL (port 563).
2.  **Folders:**
    *   Temporary Download Folder: `/downloads/incomplete`
    *   Completed Download Folder: `/downloads/complete`
    *   Permissions: `775`
3.  **Categories:**
    *   **tv:** Folder/Path `tv` -> Saves to `/downloads/complete/tv`
    *   **movies:** Folder/Path `movies` -> Saves to `/downloads/complete/movies`

### qBittorrent (`http://qbittorrent:8081`)
1.  **Authentication:** Change default (`admin`/`adminadmin` or temporary password) to a secure password.
2.  **Downloads:**
    *   Default Save Path: `/downloads/complete`
    *   Keep incomplete torrents in: `/downloads/incomplete`
    *   **Uncheck** "Append the label to the save path".
3.  **Connection:** Ensure "Listening Port" matches the port forwarded by Gluetun/Mullvad (usually `51820` or `6881` for peer traffic).

## 3. Prowlarr Configuration (Indexers)

**URL:** `http://prowlarr:9696`

1.  **Indexers:** Add your Usenet indexers (NZBGeek, etc.) and Torrent trackers.
2.  **Apps (Sync):**
    *   Add **Sonarr** (`http://sonarr:8989`) and **Radarr** (`http://radarr:7878`).
    *   Use API Keys from respective apps (Settings -> General).
    *   Prowlarr will now automatically sync indexers to Sonarr/Radarr.

## 4. Sonarr & Radarr Configuration (Media Management)

**Sonarr:** `http://sonarr:8989` | **Radarr:** `http://radarr:7878`

### Download Clients
1.  **Add SABnzbd:**
    *   Host: `sabnzbd`
    *   Port: `8080`
    *   API Key: From SABnzbd (Config -> General).
    *   Category: `tv` (Sonarr) / `movies` (Radarr).
2.  **Add qBittorrent:**
    *   Host: `qbittorrent`
    *   Port: `8081`
    *   Credentials: Your qBittorrent username/password.
    *   Category: `tv` (Sonarr) / `movies` (Radarr).

### Remote Path Mappings (CRITICAL)
Since download clients run in containers but Sonarr/Radarr run natively, paths must be mapped.

**Go to:** Settings -> Download Clients -> Remote Path Mappings -> Add (+)

**For SABnzbd:**
*   **Host:** `sabnzbd` (MUST match the client Host field exactly)
*   **Remote Path:** `/downloads/complete/`
*   **Local Path:** `/mnt/media/downloads/usenet/complete/`

**For qBittorrent:**
*   **Host:** `qbittorrent`
*   **Remote Path:** `/downloads/complete/`
*   **Local Path:** `/mnt/media/downloads/torrents/complete/`

### Root Folders
*   **Sonarr:** Set Root Folder to `/mnt/media/tv`.
*   **Radarr:** Set Root Folder to `/mnt/media/movies`.

## 5. Overseerr Configuration (Request Frontend)

**URL:** `https://overseerr`

*   **Note on HTTPS:** Accessing via `https://overseerr` is required because modern browsers (like Chrome) often force HTTPS for local hostnames. Caddy is configured with `tls internal` to provide a self-signed certificate. You may need to click "Advanced" and "Proceed" the first time you visit.
*   **UDM Pro:** Ensure a Local DNS record exists pointing `overseerr` to the host IP.
*   **Plex:** Connect to your Plex server (`plex`, port `32400`).
*   **Services:**
    *   Add **Radarr Server:** `radarr` (port `7878`). Select Quality Profile (e.g., HD-1080p) and Root Folder (`/mnt/media/movies`).
    *   Add **Sonarr Server:** `sonarr` (port `8989`). Select Quality Profile and Root Folder (`/mnt/media/tv`).
