# Media Server User Guide

This guide explains the primary workflows for using your automated media stack ("The Arr Stack").

## 1. Requesting New Content (The Primary Workflow)

**Tool:** **Overseerr** (`http://overseerr:5055`)

This is your "App Store" for movies and TV shows. You rarely need to touch the other apps.

1.  **Login:** Use your Plex account credentials.
2.  **Search:** Type the name of the movie or show you want.
3.  **Request:**
    *   Click the **Request** button.
    *   **Select Quality:** (Optional) If you want 4K specifically, change the "Quality Profile" to "Ultra-HD" (if configured). Otherwise, stick to the default (usually 1080p).
    *   **Select Root Folder:** Usually pre-selected (e.g., "Movies" or "TV").
4.  **Wait:**
    *   Overseerr sends the request to **Radarr** or **Sonarr**.
    *   They search **Prowlarr** for the best match.
    *   They send the download to **SABnzbd** (Usenet) or **qBittorrent**.
    *   Once downloaded, the file is moved to your Plex library.
    *   **Notification:** You will receive a notification (if configured) when it's ready to watch.

## 2. Managing Your Library

**Tools:** **Sonarr** (TV) / **Radarr** (Movies)

Use these tools to manage existing content, fix incorrect matches, or monitor upcoming releases.

*   **Calendar:** View a calendar of upcoming episodes or movie releases.
*   **Mass Editor:** Move series to different folders or change quality profiles for many items at once.
*   **Manual Search:** If a download fails or grabs the wrong version:
    1.  Go to the movie/show page.
    2.  Click the "Search" tab (magnifying glass).
    3.  You will see a list of all available releases. You can manually click the download icon next to a specific release.

## 3. Watching Content

**Tools:** **Plex** (`http://plex:32400`) or **Jellyfin** (`http://jellyfin:8096`)

*   **Library:** Your requested content will automatically appear in your "Movies" or "TV Shows" library in both Plex and Jellyfin.
*   **Playback:** Both servers handle transcoding and streaming to your devices. Jellyfin is a great open-source alternative if you prefer it over Plex.
*   **Audio:** For high-end audio streaming, you can also use **MiniDLNA** to stream music directly to supported network players.

## 4. Troubleshooting Downloads

**Tools:** **SABnzbd** / **qBittorrent**

If a request stays "Processing" for a long time:

1.  **Check Queue:** Look at the Activity tab in Sonarr/Radarr.
    *   Is it stuck downloading?
    *   Did the download fail? (Red icon).
2.  **Check Client:**
    *   **SABnzbd:** Is it paused? Is it out of server quota? Is it repairing a file?
    *   **qBittorrent:** Is it stalled with 0 seeders? (This is common for older torrents).
3.  **Fix:**
    *   If stalled, remove the item from the download client.
    *   Go back to Sonarr/Radarr, go to the item's "History" or "Search" tab, and mark the release as "Failed" (Blocklist) so it tries to find a different version.

## 5. System Maintenance

*   **Updates:** The stack is managed via NixOS. Run `sudo nixos-rebuild switch --flake .#classic-laddie` to apply system updates.
*   **VPN:** All downloads go through the VPN. If downloads stop working completely, check if the VPN container (`gluetun`) is running.
