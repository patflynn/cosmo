# Legacy Configuration History

This document provides an overview of the legacy configuration structures that were part of this repository before the unified migration.

## Original Repository Structure

Before the migration to a unified cross-platform configuration, the repository contained multiple separate configuration approaches:

1. **Traditional Dotfiles (2015-2022)**
   - Basic bash, zsh, tmux configurations
   - Manual installation scripts
   - Non-declarative environment setup

2. **classic-laddie NixOS Configuration**
   - Full NixOS configuration for a desktop/laptop system
   - Named "classic-laddie" (root flake.nix)
   - Used ZFS storage in later revisions

3. **nix-basic Configuration**
   - Separate NixOS configuration for a server
   - Located in the `nix-basic/` directory
   - Had its own flake.nix and modules

## Legacy Files Preserved

The legacy hardware configurations have been preserved and migrated to the new structure:

- `classic-laddie/hardware-configuration.nix` → `modules/hosts/classic-laddie/hardware-configuration.nix`
- `classic-laddie/hardware-configuration-zfs.nix` → `modules/hosts/desktop-zfs/hardware-configuration.nix`
- `nix-basic/hardware-configuration.nix` → `modules/hosts/server/hardware-configuration.nix`

Other important components have been migrated to more appropriate locations in the new structure:
- Git configuration → `home/common/git.nix`
- Gitsign package → `pkgs/gitsign.nix`
- i3 and window manager settings → `home/linux/i3.nix`
- Shell configurations → `home/common/zsh.nix`

## Migration Strategy

The migration followed these principles:
1. Preserve critical hardware-specific configurations
2. Unify common elements across systems
3. Create a modular structure with clear separation of concerns
4. Enable cross-platform reuse of configurations
5. Move toward a fully declarative system configuration

## Using Legacy Hardware Configurations

When deploying to real hardware, you may need to copy or adapt the legacy hardware configurations. Each host-specific directory includes both the real hardware configuration and a CI-compatible version (commented out).

For proper deployment, ensure you're using the correct hardware configuration for your specific system.