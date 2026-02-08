# Debian Workstation Setup Guide

This guide describes how to bootstrap a generic Debian-based environment (e.g., a standard VM, a cloud instance, or a physical machine) using the Home Manager configurations from this flake.

## Available Profiles

| Profile | Username | Use Case |
|---------|----------|----------|
| `personal` | patrick | Personal Debian/Ubuntu workstations |
| `paflynn@bushmills` | paflynn | Work environment (custom home directory) |
| `crostini` | patrick | ChromeOS Crostini containers |

## Prerequisites

*   A running Debian-based system (Debian 12+, Ubuntu 24.04+, etc.)
*   Root access (sudo)
*   Internet connection

## 1. Install Nix

We use the Determinate Systems installer for a reliable, multi-user Nix installation with Flakes enabled by default.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

After installation, close and reopen your terminal (or log out and back in) to ensure Nix is in your path.

## 2. Enable Flakes (if not already enabled)

The Determinate Systems installer usually handles this, but verify by checking `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`. It should contain:

```
experimental-features = nix-command flakes
```

## 3. Bootstrap Home Manager

Run one of the following commands to apply the configuration. These targets are pure and fully reproducible.

**For Personal Use:**
```bash
nix run home-manager -- switch --flake github:patflynn/cosmo#personal
```

**For Work Use:**
```bash
nix run home-manager -- switch --flake 'github:patflynn/cosmo#paflynn@bushmills'
```

**For Crostini (ChromeOS):**
```bash
nix run home-manager -- switch --flake github:patflynn/cosmo#crostini
```

## 4. Direnv Integration

After the first run, `direnv` should be installed. Hook it into your shell to automatically load development environments.

Add the following to the end of your `~/.bashrc` (if it wasn't added automatically):

```bash
eval "$(direnv hook bash)"
```

Then, reload your shell:
```bash
source ~/.bashrc
```

## Troubleshooting

*   **"experimental Nix feature 'nix-command' is disabled"**: Ensure you have `experimental-features = nix-command flakes` in your `nix.conf`.
*   **Locales**: If you see locale warnings, ensure you have generated the `en_US.UTF-8` locale on your Debian host (`sudo dpkg-reconfigure locales`).
