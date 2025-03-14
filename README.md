# Cosmo: Cross-Platform NixOS Configuration

A unified NixOS configuration system for desktops, servers, macOS, and ChromeOS.

[![NixOS Configuration Test](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml)
[![Nix Format Check](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml)

## Overview

This repository contains unified configurations for multiple systems:

- **NixOS Desktop/Laptop**: Full system configuration for Linux desktops
- **NixOS Server**: Minimal configuration for home servers
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
│       └── server/     # Server configuration
├── home/               # Home-manager configurations
│   ├── common/         # Shared home-manager config
│   ├── linux/          # Linux-specific home config
│   └── darwin/         # macOS-specific home config
├── pkgs/               # Custom package definitions
└── docs/               # Documentation
    └── legacy.md       # Legacy configuration history
```

## Usage

### NixOS Desktop

```bash
sudo nixos-rebuild switch --flake github:patflynn/cosmo#desktop
```

### NixOS Server

```bash
sudo nixos-rebuild switch --flake github:patflynn/cosmo#server
```

### macOS

```bash
darwin-rebuild switch --flake github:patflynn/cosmo#macbook
```

### ChromeOS

```bash
home-manager switch --flake github:patflynn/cosmo#chromeos
```

## Migration Notes

This repository has undergone a significant restructuring to unify configurations across platforms. The legacy configuration files are preserved locally but removed from git tracking. See [docs/legacy.md](docs/legacy.md) for details on the migration and preservation of hardware-specific configurations.

## Testing Status

Testing documentation and procedures are available in the GitHub issues:
- [Test and finalize desktop configuration](https://github.com/patflynn/cosmo/issues/12)
- [Test and finalize server configuration](https://github.com/patflynn/cosmo/issues/13)
- [Test and finalize macOS configuration](https://github.com/patflynn/cosmo/issues/14)
- [Test and finalize ChromeOS configuration](https://github.com/patflynn/cosmo/issues/15)
