# Media Server Setup Guide (2025)

This guide details the setup and configuration of the "State of the Art" media server stack in Cosmo, utilizing native NixOS services for the application layer and a secure containerized environment for networking.

## 1. The Stack

*   **Media Server:** [Plex](https://www.plex.tv/) (Native). Hardware accelerated (NVENC).
*   **Request Manager:** [Overseerr](https://overseerr.dev/) (Native). "Netflix-like" request interface for Plex.
*   **Automation (The Arrs):**
    *   **Sonarr:** TV Shows
    *   **Radarr:** Movies
    *   **Prowlarr:** Indexer Manager (Syncs to Sonarr/Radarr)
*   **Downloaders:**
    *   **SABnzbd:** Usenet Downloader (Containerized).
    *   **qBittorrent:** Torrent Downloader (Containerized).
*   **Security:**
    *   **Gluetun:** VPN Client Container. Acts as a network gateway for qBittorrent and SABnzbd to prevent IP leaks.

## 2. Prerequisites

1.  **Nvidia GPU (Recommended):** The module is optimized for NVENC hardware acceleration (Plex Pass required for hardware transcoding).
2.  **Mullvad VPN Account:** Required for the secure torrenting tunnel.
3.  **Storage:** A large storage pool mounted at `/mnt/media`.

## 3. Installation

The setup is modularized in `modules/media-server/default.nix`.

### Step 1: Create the VPN Secret
We use **Agenix** to store your VPN credentials securely.

1.  Enter the development shell:
    ```bash
    nix develop
    ```
2.  Edit/Create the secret file (must be run from the secrets directory):
    ```bash
    cd secrets
    agenix -e media-vpn.age
    ```
3.  Paste your Mullvad WireGuard configuration in the following format (Key=Value):
    ```env
    WIREGUARD_PRIVATE_KEY=your_private_key_here
    WIREGUARD_ADDRESSES=10.xx.xx.xx/32
    ```
    *Get these details from the [Mullvad WireGuard Configuration Generator](https://mullvad.net/en/account/#/wireguard-config).*

### Step 2: Enable the Module
In your host configuration (e.g., `hosts/classic-laddie/default.nix`):

1.  **Import the module:**
    ```nix
    imports = [
      ../../modules/media-server/default.nix
    ];
    ```
2.  **Enable the service:**
    ```nix
    modules.media-server.enable = true;
    ```
3.  **Map the Secret:**
    ```nix
    age.secrets."media-vpn" = {
      file = ../../secrets/media-vpn.age;
      owner = "patrick"; # Must be readable by the user running the container
      group = "root";
      mode = "0400";
    };
    ```

## 4. Usage & Ports

Once deployed (`nixos-rebuild switch ...`), the services will be available at the host's IP address:

| Service | Port | Description |
| :--- | :--- | :--- |
| **Plex** | `32400` | Media Player UI (Web) |
| **Overseerr** | `5055` | Request UI (Start here!) |
| **Sonarr** | `8989` | TV Management |
| **Radarr** | `7878` | Movie Management |
| **Prowlarr** | `9696` | Indexer Config |
| **SABnzbd** | `8080` | Usenet Client |
| **qBittorrent** | `8081` | Torrent Client (via VPN) |

## 5. First-Time Configuration

### 5.1. Claiming the Plex Server (Crucial Step)
Since the server is headless, Plex may not allow you to "Claim" it (link it to your account) from a remote IP. You must use an SSH tunnel to access it as if you were on `localhost`.

1.  **Open an SSH Tunnel** from your laptop/desktop:
    ```bash
    ssh -L 8888:localhost:32400 patrick@classic-laddie
    ```
2.  **Open in Browser:** Go to `http://localhost:8888/web`.
3.  **Sign In:** You should now see the setup wizard to claim the server.
4.  **Finish:** Once claimed, you can disconnect SSH and access it normally via `http://<server-ip>:32400`.

### 5.2. App Configuration
1.  **Prowlarr:**
    *   Add your Indexers (Usenet/Torrents).
    *   Connect Prowlarr to Sonarr and Radarr (Settings -> Apps).
2.  **Overseerr:**
    *   Connect to your Plex server (sign in with Plex account).
    *   Connect to your Sonarr/Radarr instances.
3.  **qBittorrent & SABnzbd:**
    *   **Critical:** Verify your IP. Use the "Execution Log" (qBit) or "Status" (SAB) to ensure the detected external IP matches your Mullvad VPN IP.

## 6. State & Backups

Unlike the system configuration (managed by Nix), your application data (Plex database, Sonarr history, downloaded files) is **stateful**.

*   **Config Location:** Application data lives in `/var/lib/` (e.g., `/var/lib/plex`, `/var/lib/sonarr`, `/var/lib/sabnzbd`).
*   **Persistence:** These directories persist across reboots and `nixos-rebuild` operations.
*   **Backup Strategy:** To backup your library metadata and settings, backup these directories.