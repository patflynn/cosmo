# Track Plan: Debian Workstation Setup (Generic Roles)

## Phase 1: Module Refactoring
*Goal: Create the reusable "Generic Linux" foundation.*

- [x] Task: Create `home/generic-linux.nix`
    - [x] Subtask: Create file importing `./dev.nix`.
    - [x] Subtask: Set `targets.genericLinux.enable = true;` to ensure Home Manager works on non-NixOS.
    - [x] Subtask: Ensure `programs.direnv` is enabled (either here or verify it's in `dev.nix`).
    - [x] Subtask: Verify syntax `nix fmt`.
- [x] Task: Refactor `home/crostini.nix`
    - [x] Subtask: Update `home/crostini.nix` to import `./generic-linux.nix` instead of duplicating logic.
    - [x] Subtask: Remove any logic that is now redundant with `generic-linux.nix`.
    - [x] Subtask: Verify syntax `nix fmt`.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Module Refactoring' (Protocol in workflow.md) [checkpoint: 8a0ffeb059d04ea1db5adff0d469058899abd198]

## Phase 2: Flake Configuration
*Goal: Expose the generic roles in flake.nix.*

- [x] Task: Define `patrick@debian` in `flake.nix`
    - [x] Subtask: Add `homeConfigurations."patrick@debian"` entry.
    - [x] Subtask: Configure it to use `pkgs.x86_64-linux` and import `./home/generic-linux.nix`.
- [x] Task: Define `patrick@crostini` in `flake.nix`
    - [x] Subtask: Add `homeConfigurations."patrick@crostini"` entry.
    - [x] Subtask: Configure it to import `./home/crostini.nix`.
    - [x] Subtask: Ensure `bud-lite` legacy entry points to this new config or is removed.
- [x] Task: Verify Flake
    - [x] Subtask: Run `nix flake check` to ensure the new outputs are valid.
    - [x] Subtask: Run `nix run home-manager -- switch --flake .#patrick@debian --dry-run` (if feasible locally) or verify instantiation.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Flake Configuration' (Protocol in workflow.md) [checkpoint: 52e759836740e3b2ad84c7584a0195ab56f227cc]

## Phase 3: Documentation
*Goal: Create the Setup Guide.*

- [ ] Task: Create `docs/debian-setup.md`
    - [ ] Subtask: Write instructions for installing Nix (Determinate Systems installer recommended).
    - [ ] Subtask: Write instructions for enabling Flakes.
    - [ ] Subtask: Write instructions for running `nix run home-manager -- switch --flake github:patflynn/cosmo#patrick@debian`.
    - [ ] Subtask: Add note about `direnv` integration (hooking into shell).
- [ ] Task: Update `docs/bud-lite-setup.md`
    - [ ] Subtask: Update references to point to the new `#patrick@crostini` generic role.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Documentation' (Protocol in workflow.md)
