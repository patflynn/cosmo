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
nix run home-manager/master -- switch --flake github:patflynn/cosmo#crostini
```

### 4. Set Default Shell

Home Manager installs Zsh but cannot change your login shell on Debian. You must do this manually. Standard `chsh` often fails in Crostini due to PAM issues, so a direct edit of `/etc/passwd` is recommended:

1.  Add the Nix Zsh path to valid shells:
    ```bash
    command -v zsh | sudo tee -a /etc/shells
    ```

2.  Change your default shell (bypasses `chsh` PAM errors):
    ```bash
    sudo sed -i "s|$SHELL|$(command -v zsh)|" /etc/passwd
    ```

Log out and log back in for this to take effect.

## Updates

To update the configuration later:

```bash
home-manager switch --flake github:patflynn/cosmo#crostini
```
