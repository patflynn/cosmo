# Track Plan: Establish the "Cosmo" Foundation & TUI

## Phase 1: Modular Refactoring
*Goal: Restructure the Nix modules to support composability.*

- [ ] Task: Analyze and Map Current Modules
    - [ ] Subtask: Audit `modules/` and `hosts/` to identify reusable patterns.
    - [ ] Subtask: Create a mapping document (scratchpad) for the new `roles` and `features` structure.
- [ ] Task: Create Module Directory Structure
    - [ ] Subtask: Create `modules/core`, `modules/roles`, `modules/features`.
    - [ ] Subtask: Move `modules/common/system.nix` -> `modules/core/default.nix`.
- [ ] Task: Refactor Core Module
    - [ ] Subtask: Ensure `modules/core` contains only universal settings (Nix settings, locale, basic shell).
    - [ ] Subtask: Verify `flake check` (Red/Green loop).
- [ ] Task: Create Workstation Role
    - [ ] Subtask: Extract GUI-related configs from `hosts/classic-laddie` and `modules/common/workstation.nix`.
    - [ ] Subtask: Create `modules/roles/workstation/default.nix`.
- [ ] Task: Refactor 'Classic Laddie' Host
    - [ ] Subtask: Update `hosts/classic-laddie/default.nix` to import `modules/core` and `modules/roles/workstation`.
    - [ ] Subtask: Verify build `nixos-rebuild build --flake .#classic-laddie --dry-run`.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Modular Refactoring' (Protocol in workflow.md)

## Phase 2: TUI Implementation
*Goal: Create the `cosmo-ctl` tool for system management.*

- [ ] Task: Package `gum` or Select Tool
    - [ ] Subtask: Check if `gum` is available in `nixpkgs`.
    - [ ] Subtask: Add `gum` (or `fzf`) to `modules/core` environment packages.
- [ ] Task: Create `cosmo-ctl` Script Skeleton
    - [ ] Subtask: Create `pkgs/cosmo-ctl/default.nix` (or inline in module).
    - [ ] Subtask: Write basic script that prints "Hello Cosmo".
    - [ ] Subtask: Test: Build the package/module.
- [ ] Task: Implement Main Menu
    - [ ] Subtask: Update script to show menu options: "Rebuild", "Network", "Update", "Exit".
    - [ ] Subtask: Test: Run script and verify menu appears.
- [ ] Task: Implement Rebuild Logic
    - [ ] Subtask: Connect "Rebuild" option to `sudo nixos-rebuild switch --flake /etc/nixos`.
- [ ] Task: Implement Network Logic
    - [ ] Subtask: Connect "Network" option to `nmtui`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: TUI Implementation' (Protocol in workflow.md)

## Phase 3: Documentation & Polish
*Goal: Update documentation to reflect the new structure and tools.*

- [ ] Task: Update README
    - [ ] Subtask: Add section on "Directory Structure" (Roles/Features).
    - [ ] Subtask: Add section on "Using cosmo-ctl".
- [ ] Task: Update AGENTS.md
    - [ ] Subtask: Add the strict Git Workflow rules defined in `conductor/workflow.md`.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Documentation & Polish' (Protocol in workflow.md)
