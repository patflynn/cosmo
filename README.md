# Cosmo: Cross-Platform NixOS Configuration

> ## ⚠️ WARNING: EXPERIMENTAL CONFIGURATIONS ⚠️
> **Most configurations in this repository have not been thoroughly tested (OR AT ALL!) and should NOT be used in any environments!** 
> 
> **These are primarily reference configurations for learning purposes. Use at your own risk.**

A unified NixOS configuration system for desktops, servers, macOS, and ChromeOS.

[![NixOS Configuration Test](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml)
[![Nix Format Check](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml)
[![Daily Package Updates](https://github.com/patflynn/cosmo/actions/workflows/daily-update.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/daily-update.yml)

## Overview

This repository contains unified configurations for multiple systems:

- **NixOS Desktop/Laptop**: Full system configuration for Linux desktops
- **NixOS Server**: Minimal configuration for home servers
- **WSL2**: NixOS configuration for Windows Subsystem for Linux
- **macOS**: Using nix-darwin for system configuration
- **ChromeOS**: Using standalone home-manager

## Repository Structure

```
cosmo/
├── flake.nix           # Main entry point for all configurations
├── modules/            # NixOS modules
│   ├── common/         # Shared NixOS configuration
│   └── hosts/          # Host-specific configurations
│       ├── desktop/    # Desktop configuration
│       ├── desktop-zfs/# ZFS-based desktop configuration
│       ├── server/     # Server configuration
│       └── wsl2/       # WSL2 configuration
├── home/               # Home-manager configurations
│   ├── common/         # Shared home-manager config
│   ├── linux/          # Linux-specific home config
│   └── darwin/         # macOS-specific home config
├── pkgs/               # Custom package definitions
└── docs/               # Documentation
    └── legacy.md       # Legacy configuration history
```

## Setup Prerequisites

### For All Platforms

1. **Install Nix**:
   ```bash
   # For multi-user installation (recommended):
   sh <(curl -L https://nixos.org/nix/install) --daemon
   
   # For single-user installation:
   sh <(curl -L https://nixos.org/nix/install) --no-daemon
   ```

2. **Enable Flakes**:
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

3. **Clone Repository**:
   ```bash
   git clone https://github.com/patflynn/cosmo.git
   cd cosmo
   ```

### NixOS-Specific Setup

1. **Install NixOS**: If you're starting from scratch, install NixOS by following the [official installation guide](https://nixos.org/manual/nixos/stable/index.html#sec-installation).

2. **Add Hardware Configuration**:
   ```bash
   # Copy your existing hardware configuration
   sudo cp /etc/nixos/hardware-configuration.nix modules/hosts/desktop/
   
   # Or use the ZFS configuration if applicable
   # sudo cp /etc/nixos/hardware-configuration.nix modules/hosts/desktop-zfs/
   ```

3. **Adjust Host Settings**: Edit `modules/hosts/desktop/default.nix` or `modules/hosts/server/default.nix` to update hostname, network settings, etc.

### macOS-Specific Setup

1. **Install nix-darwin**:
   ```bash
   nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
   ./result/bin/darwin-installer
   ```

2. **Install Home Manager**:
   ```bash
   nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
   nix-channel --update
   ```

3. **Configure System**:
   If using an Intel Mac, edit `flake.nix` to change `aarch64-darwin` to `x86_64-darwin` in the macbook configuration.

### WSL2-Specific Setup

1. **Install WSL2**:
   ```powershell
   # Open PowerShell as Administrator and run:
   wsl --install
   ```

2. **Install NixOS on WSL2**:
   - Download the latest NixOS-WSL tarball from [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases)
   - Create a directory for NixOS: `mkdir C:\NixOS`
   - Import the tarball: `wsl --import NixOS C:\NixOS path\to\nixos-wsl.tar.gz --version 2`
   - Start NixOS: `wsl -d NixOS`

3. **Set Up User Account**:
   ```bash
   # Create a new user (as root)
   useradd -m -G wheel -s /bin/sh username
   passwd username
   
   # Edit sudoers to allow wheel group
   visudo  # Uncomment: %wheel ALL=(ALL) ALL
   ```

4. **Clone and Apply Configuration**:
   ```bash
   # Switch to your user
   su - username
   
   # Clone repository and apply configuration
   mkdir -p ~/hack
   cd ~/hack
   git clone https://github.com/patflynn/cosmo.git
   cd cosmo
   
   # Apply configuration
   sudo nixos-rebuild switch --flake .#wsl2
   ```

For detailed WSL2 setup instructions, see [docs/wsl2-setup.md](docs/wsl2-setup.md).

### ChromeOS-Specific Setup

1. **Enable Linux (Crostini)**:
   - Open Chrome OS Settings
   - Go to "Linux development environment" section
   - Click "Turn On" and follow the setup instructions

2. **Install Nix**: Inside the Linux container:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --no-daemon
   ```

3. **Install Home Manager**:
   ```bash
   nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
   nix-channel --update
   ```

## Usage Instructions

### NixOS Desktop

```bash
# Test without making changes
sudo nixos-rebuild test --flake .#desktop

# Apply changes
sudo nixos-rebuild switch --flake .#desktop
```

### NixOS Server

```bash
# Test without making changes
sudo nixos-rebuild test --flake .#server

# Apply changes
sudo nixos-rebuild switch --flake .#server
```

### WSL2

```bash
# Test without making changes
sudo nixos-rebuild test --flake .#wsl2

# Apply changes
sudo nixos-rebuild switch --flake .#wsl2
```

### macOS

```bash
# Test without making changes
darwin-rebuild check --flake .#macbook

# Apply changes
darwin-rebuild switch --flake .#macbook
```

### ChromeOS

```bash
# Test without making changes
home-manager build --flake .#chromeos

# Apply changes
home-manager switch --flake .#chromeos
```

## Customization

### Adding Packages

1. **System-wide Packages** (NixOS): Edit `modules/common/default.nix` or the host-specific configuration in `modules/hosts/<host>/default.nix`.

2. **User Packages**: 
   - For all platforms: Edit `home/common/default.nix`
   - For platform-specific packages: Edit `home/linux/default.nix` or `home/darwin/default.nix`

### Adding Custom Configuration

1. **Create a new module**: Create a file in the appropriate directory:
   ```bash
   # For a new service in NixOS
   touch modules/common/myservice.nix
   
   # For a new application configuration
   touch home/common/myapp.nix
   ```

2. **Import the new module**: Add an import statement in the appropriate default.nix file.

## Migration Notes

This repository has undergone a significant restructuring to unify configurations across platforms. The legacy configuration files are preserved locally but removed from git tracking. See [docs/legacy.md](docs/legacy.md) for details on the migration and preservation of hardware-specific configurations.

## Testing Status

Testing documentation and procedures are available in the GitHub issues:
- [Test and finalize desktop configuration](https://github.com/patflynn/cosmo/issues/12)
- [Test and finalize server configuration](https://github.com/patflynn/cosmo/issues/13)
- [Test and finalize macOS configuration](https://github.com/patflynn/cosmo/issues/14)
- [Test and finalize ChromeOS configuration](https://github.com/patflynn/cosmo/issues/15)

## Troubleshooting

### Common Issues

1. **Configuration doesn't apply**: Make sure you're using the correct flake target and have the right permissions.

2. **Hardware detection issues**: Ensure your hardware configuration is correctly set up in the host-specific directory.

3. **Package conflicts**: Check for conflicting packages and use overlays to resolve them.

### Getting Help

If you encounter issues, check:
1. The [NixOS Wiki](https://nixos.wiki/)
2. The [NixOS Discourse](https://discourse.nixos.org/)
3. Or file an issue in this repository
