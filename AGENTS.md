# AGENTS.md - Context & Instructions for AI Agents

This repository (`cosmo`) is a **Nix Flake** configuration for managing NixOS systems and Home Manager profiles.

## Project Structure & Architecture

The project follows a **Host-Centric** and **Layered** architecture.

- **`flake.nix`**: The entry point. Defines `nixosConfigurations` for each host (e.g., `classic-laddie`, `wsl`).
- **`hosts/`**: Contains host-specific configurations.
  - Each directory (e.g., `hosts/classic-laddie/`) should contain a `default.nix` (configuration) and `hardware-configuration.nix`.
  - **`classic-laddie`** acts as the physical host for virtual workstations (e.g., **`johnny-walker`**).
- **`home/`**: Home Manager configurations (User: `patrick`).
  - **`common.nix`**: Base configuration shared across all machines (shell, git, core tools).
  - **`*.nix`** (e.g., `server.nix`, `wsl.nix`): Host/Context-specific overrides that import `common.nix`.
  - **Note**: Home Manager is integrated as a NixOS module in `flake.nix`, not standalone.
- **`modules/`**: Reusable NixOS modules.
  - `modules/common/system.nix`: Base system configuration (locale, basic packages) imported by all hosts.
- **`secrets/`**: Encrypted secrets and access control.
  - Managed via **Agenix**.
  - `secrets.nix`: Defines access rules (public keys) for encrypted files.
  - `*.age`: Encrypted binary files containing actual secrets.

## Development Guidelines

### 1. Conventions
- **Language**: Nix.
- **Formatting**: 2-space indentation.
- **Style**: Functional, declarative. Prefer `modules` over ad-hoc shell scripts.
- **Imports**: Explicitly import dependencies.

### 2. Workflow Rules
- **No Direct Commits**: NEVER commit directly to the `main` branch.
- **Pull Requests**: All changes must be submitted via a Pull Request (PR) from a feature or fix branch.
- **Branch Naming**: Use descriptive branch names (e.g., `feat/add-monitoring`, `fix/typo-in-readme`).

### 3. Version Control Strategy (Jujutsu / jj)
We prefer **Jujutsu (jj)** for local development, especially for managing stacked changes.

**Key Commands:**
- **Status/Log**: `jj st` (see working copy), `jj log` (graph view).
- **Commit**: `jj commit -m "feat(scope): message"` (creates a new change on top).
- **Edit**: `jj edit <change_id>` (switch to a specific commit to modify it).
- **Squash/Amend**: `jj squash` (move changes from working copy into parent commit).
- **Push**: `jj git push` (pushes the current stack to the git remote).

**Workflow for Agents:**
1.  When starting a task, assume you are in a `jj` repo (backed by git).
2.  Use standard git commands (`git checkout -b ...`) for compatibility if `jj` is not available or if specifically asked.
3.  However, when managing complex, dependent features (e.g., Feature A depends on Feature B), prefer `jj`'s stacked commit model over Git's manual rebasing.

### 4. Common Tasks

#### Rebuild System
Apply changes to the current system:
```bash
sudo nixos-rebuild switch --flake .
