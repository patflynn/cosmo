# Track Spec: Establish the "Cosmo" Foundation & TUI

## Context
The "Cosmo" NixOS repository requires restructuring to support the new "Product Guide" goals: increased modularity, ease of bootstrapping, and improved user experience via a TUI. Currently, the configuration is functional but monolithic in places, making it hard to compose new hosts.

## Requirements
1.  **Refactor for Modularity:**
    *   Reorganize `modules/` into clear functional areas (e.g., `roles`, `features`).
    *   Ensure host configurations (e.g., `classic-laddie`) are composed primarily of these modules rather than ad-hoc config.
2.  **TUI Settings Menu (`cosmo-ctl`):**
    *   Create a CLI/TUI entry point for common system tasks.
    *   **Features:**
        *   Network Management (Launch `nmtui`).
        *   System Rebuild (Trigger `nixos-rebuild switch`).
        *   System Update (Trigger `nix flake update` + rebuild).
        *   Garbage Collection (Trigger `nix-collect-garbage`).
3.  **Bootstrapping Support:**
    *   Ensure the new structure allows for a clear "install" path (documented in README).

## Technical Design

### 1. Directory Structure Changes
Proposed structure for `modules/`:
```
modules/
├── core/           # Base system config (users, locale, nix settings) - applied to ALL
├── roles/          # High-level archetypes
│   ├── workstation # UI, Audio, Fonts
│   ├── server      # Headless, SSH hardening
│   └── laptop      # Power management, Wifi
├── features/       # Specific capabilities
│   ├── gaming      # Steam, drivers
│   ├── virt        # Libvirt, Docker
│   ├── hyprland    # The desktop environment
│   └── media       # Plex, *arr (Existing/Deployed)
```

### 2. TUI Implementation
*   **Language:** Bash
*   **Dependencies:** `gum` (Charm.sh) is preferred for modern aesthetics if available in nixpkgs, otherwise `dialog` or simple `fzf`.
    *   *Decision:* Use `gum` if packaging is trivial, else fallback to `fzf` menu.
*   **Location:** `bin/cosmo-ctl` (will need to be added to `environment.systemPackages`).

### 3. Git Workflow Enforcement
*   While the agent follows the workflow, the *repo* should encourage it.
*   Add a `CONTRIBUTING.md` (or update AGENTS.md) with the specific git rules.

## Acceptance Criteria
*   [ ] `flake.nix` builds successfully after refactoring.
*   [ ] `classic-laddie` host boots and retains previous functionality.
*   [ ] `cosmo-ctl` command launches a menu.
*   [ ] "Rebuild" option in `cosmo-ctl` successfully runs a rebuild.
