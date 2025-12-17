# AGENTS.md - Context & Instructions for AI Agents

This repository (`cosmo`) is a **Nix Flake** configuration for managing NixOS systems and Home Manager profiles.

## Project Structure & Architecture

The project follows a **Host-Centric** and **Layered** architecture.

- **`flake.nix`**: The entry point. Defines `nixosConfigurations` for each host (e.g., `classic-laddie`, `wsl`).
- **`hosts/`**: Contains host-specific configurations.
  - Each directory (e.g., `hosts/classic-laddie/`) should contain a `default.nix` (configuration) and `hardware-configuration.nix`.
  - **`classic-laddie`** is the physical server.
- **`home/`**: Home Manager configurations (User: `patrick`).
  - **`common.nix`**: Base configuration shared across all machines (shell, git, core tools).
  - **`*.nix`** (e.g., `server.nix`, `wsl.nix`): Host/Context-specific overrides that import `common.nix`.
  - **Note**: Home Manager is integrated as a NixOS module in `flake.nix`, not standalone.
- **`modules/`**: Reusable NixOS modules.
  - `modules/common/system.nix`: Base system configuration (locale, basic packages) imported by all hosts.
- **`old-mess/`**: Legacy configuration (reference only, do not modify or use unless migrating).

## Development Guidelines

### 1. Conventions
- **Language**: Nix.
- **Formatting**: 2-space indentation.
- **Style**: Functional, declarative. Prefer `modules` over ad-hoc shell scripts.
- **Imports**: Explicitly import dependencies.

### 2. Common Tasks

#### Rebuild System
Apply changes to the current system:
```bash
sudo nixos-rebuild switch --flake .
```
(Or `--flake .#hostname` if strictly necessary, but auto-detection usually works).

#### Managing Packages
- **System-wide** (available to root & all users):
  - Edit `modules/common/system.nix` (for all hosts) or `hosts/<hostname>/default.nix` (for specific host).
  - Add to `environment.systemPackages`.
- **User-specific** (Home Manager):
  - Edit `home/common.nix` (for all hosts) or `home/<context>.nix` (for specific context).
  - Add to `home.packages`.

### 3. Contribution Workflow
- **Branch Protection**: The `main` branch is protected. All changes must be submitted via Pull Requests (PRs).
- **Commit Style**: Use declarative commit messages (e.g., "feat: Add new feature", "fix: Resolve bug").

## Contextual Knowledge
- **User**: The primary configured user in Nix modules is `patrick`.
- **WSL**: The `wsl` host configuration handles Windows Subsystem for Linux specifics.
- **Virtualization**: `johnny-walker` is a standalone VM (QEMU/KVM).