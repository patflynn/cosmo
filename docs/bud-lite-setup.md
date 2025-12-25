# Bud-Lite Setup (Debian + Home Manager)

`bud-lite` is configured as a standalone Home Manager setup running on top of Debian (specifically inside a Chromebook Crostini container).

## Prerequisites

1.  A device running ChromeOS with Linux (Crostini) enabled.
2.  Debian 12 (Bookworm) or later (standard Crostini container).

## Bootstrap Instructions

### 1. Install Nix

Multi-user installation is recommended:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### 2. Configure Nix

Enable flakes and experimental features. Edit `/etc/nix/nix.conf` (create if missing):

```conf
experimental-features = nix-command flakes
```

Restart the nix-daemon:
```bash
sudo systemctl restart nix-daemon
```

### 3. Install Home Manager & Switch

Apply the configuration from the flake:

```bash
nix run home-manager/master -- switch --flake github:patflynn/cosmo#patrick@bud-lite
```

## Updates

To update the configuration later:

```bash
home-manager switch --flake github:patflynn/cosmo#patrick@bud-lite
```
