# Track Spec: Debian Workstation Setup (Generic Roles)

## Overview
This track aims to create a "Nix as a Package Manager" configuration specifically tailored for Debian-based environments (Generic VMs and Crostini containers) that lack dedicated GPUs. The goal is to move away from unique per-host entries in `flake.nix` and instead establish **Generic Role Configurations**. This allows the same configuration profile to be applied to multiple machines (e.g., multiple Debian VMs or Crostini containers) without modifying the flake.

## Functional Requirements
1.  **Refactor Existing Configs:**
    *   Extract the core "Headless/CLI" logic from `home/crostini.nix` into a reusable module (e.g., `home/headless.nix` or `home/profiles/headless-debian.nix`).
2.  **Define Generic Home Manager Roles:**
    *   Create `patrick@debian`: A generic profile for standard Debian VMs, importing the headless core.
    *   Create `patrick@crostini`: A generic profile for ChromeOS containers, importing the headless core + Crostini-specific overrides (replacing the specific `bud-lite` entry).
3.  **Package Set:**
    *   **Core:** Zsh, Git, standard utils (`home/common.nix`).
    *   **Dev:** LSPs, languages, build tools (`home/dev.nix`).
    *   **Exclude:** GPU-heavy apps.
    *   **Include:** TUI alternatives (Emacs, Vim).
4.  **Documentation:**
    *   Create `docs/debian-setup.md`.
    *   Document how to bootstrap any Debian machine using the `patrick@debian` role.
    *   Update `bud-lite-setup.md` to reflect the new `patrick@crostini` generic role.

## Non-Functional Requirements
*   **Reusability:** The `headless` module must be the shared foundation for both Debian and Crostini roles.
*   **Scalability:** The solution must allow spinning up N new VMs without any code changes in the repo.

## Acceptance Criteria
*   [ ] `home/headless.nix` (or similar) created with shared config.
*   [ ] `flake.nix` defines `homeConfigurations."patrick@debian"` and `homeConfigurations."patrick@crostini"`.
*   [ ] `bud-lite` specific entry is removed or aliased to the generic Crostini role.
*   [ ] `nix run home-manager -- switch --flake .#patrick@debian` works on a generic VM.
*   [ ] `docs/debian-setup.md` is created.