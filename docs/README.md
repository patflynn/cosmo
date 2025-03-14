# Cross-Platform NixOS Configuration Documentation

This directory contains documentation for the unified NixOS configuration system.

## Overview

The repository is structured to support multiple platforms:

1. **NixOS Linux** - Full system configuration for desktop and server
2. **macOS** - Using nix-darwin for system configuration
3. **ChromeOS** - Using standalone home-manager

## Directory Structure

```
cosmo/
├── flake.nix           # Main entry point for all configurations
├── modules/            # NixOS modules
│   ├── common/         # Shared NixOS configuration
│   └── hosts/          # Host-specific configurations
│       ├── desktop/    # Desktop configuration
│       └── server/     # Server configuration
├── home/               # Home-manager configurations
│   ├── common/         # Shared home-manager config
│   ├── linux/          # Linux-specific home config
│   └── darwin/         # macOS-specific home config
└── docs/               # Documentation
```

## Configuration Types

### System Configurations

- **desktop**: Full NixOS configuration for desktop usage
- **server**: Minimal NixOS configuration for server usage

### Home-Manager Configurations

- **linux**: Configuration for Linux (NixOS and ChromeOS)
- **darwin**: Configuration for macOS

## Usage

### NixOS Desktop/Laptop

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

### ChromeOS (Home Manager standalone)

```bash
home-manager switch --flake github:patflynn/cosmo#chromeos
```

## Adding a New System

1. Create a new host configuration in `modules/hosts/[hostname]/`
2. Add the system to the appropriate section in `flake.nix`