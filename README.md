# cosmo

Cross-platform NixOS configuration for desktops, servers, macOS, and ChromeOS.

[![NixOS Configuration Test](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml)
[![Nix Format Check](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml)

## Overview

This repository contains unified configurations for multiple systems:

- **NixOS Desktop/Laptop**: Full system configuration for Linux desktops
- **NixOS Server**: Minimal configuration for home servers
- **macOS**: Using nix-darwin for system configuration
- **ChromeOS**: Using standalone home-manager

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

## Structure

```
cosmo/
├── flake.nix           # Main entry point for all configurations
├── modules/            # NixOS modules
│   ├── common/         # Shared NixOS configuration
│   └── hosts/          # Host-specific configurations
├── home/               # Home-manager configurations
│   ├── common/         # Shared home-manager config
│   ├── linux/          # Linux-specific home config
│   └── darwin/         # macOS-specific home config
└── docs/               # Documentation
```

## Legacy Install

```bash
curl -L https://raw.githubusercontent.com/patflynn/cosmo/master/install.sh | sh
```

For more detailed documentation, see the [docs](./docs/) directory.
