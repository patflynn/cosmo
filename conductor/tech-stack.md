# Tech Stack: Cosmo

## Core Infrastructure
*   **Operating System:** NixOS (Tracking `nixos-unstable` / `nixos-25.05` prerelease)
*   **Package Management:** Nix Flakes
*   **User Configuration:** Home Manager (Integrated Module)
*   **Secrets Management:** Agenix

## Desktop Environment (Hyprland)
*   **Window Manager:** Hyprland
*   **Bar/Panel:** Waybar (or similar, TBD)
*   **Notification Daemon:** Mako or Dunst (TBD)
*   **Launcher:** Rofi or Wofi (TBD)
*   **Terminal:** Alacritty or Kitty (TBD)
*   **System Settings:** Custom TUI Menu (NetworkManager TUI / `nmtui`, Bluetooth, etc.)

## Development Tools
*   **Primary Editor:** Doom Emacs
*   **Secondary/Future Editor:** Neovim (Exploratory phase, low priority)
*   **Shell:** Zsh
*   **Version Control:** Git

## Configuration & Management Experience
*   **Philosophy:** "Declarative but Agile"
*   **Goal:** Minimize friction for package management and config changes.
*   **Tooling:**
    *   Optimized `rebuild` aliases/scripts.
    *   potential integration of tools like `nh` (Nix Helper) for faster builds/cleanups.
    *   Modular file structure to isolate app configs for quick edits.

## Virtualization & Deployment
*   **Hypervisor:** Libvirt / QEMU (KVM)
*   **Containers:** Docker / Podman
*   **WSL:** NixOS-WSL (for `makers-nix` host)

## Home Automation & Media
*   **Media Stack:** (TBD - likely Jellyfin/Plex, Sonarr, Radarr, etc.)
*   **Cameras:** Unifi Protect (Access via browser or RTSP)
