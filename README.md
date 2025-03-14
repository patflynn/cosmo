# cosmo

Scripts and configurations to setup my development environment.

[![NixOS Configuration Test](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nixos-test.yml)
[![Nix Format Check](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml/badge.svg)](https://github.com/patflynn/cosmo/actions/workflows/nix-fmt.yml)

## Quick Install

```
curl -L https://raw.githubusercontent.com/patflynn/cosmo/master/install.sh | sh
```

## Building

To build and activate:
```
sudo nixos-rebuild switch --flake ~/hack/cosmo --upgrade --impure
```

To test without activating:
```
sudo nixos-rebuild test --flake ~/hack/cosmo
```

## Structure

- `flake.nix`: Entry point for the configuration
- `home.nix`: Home-manager configuration
- `classic-laddie/`: Host-specific configuration for my main machine
