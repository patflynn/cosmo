# Cosmo Roadmap & Architecture

## Vision
This repository (`cosmo`) is the single source of truth for all computing infrastructure. 
It defines the hardware, operating system, services, and user environments for the home server (`classic-laddie`) and future devices.

## Core Principles
1.  **Declarative:** If it isn't in git, it doesn't exist.
2.  **Locked Down:** The host OS should be minimal. Services run in isolation (VMs/Containers).
3.  **Ergonomic:** A unified user experience (shell, editors, keys) across all environments.

## Architecture Strategy
* **Host OS (`classic-laddie`):** * Minimal NixOS install.
    * Role: Hypervisor & Storage Controller.
    * No direct user applications (no dev tools on bare metal).
    * Remote Access via SSH and Tailscale only.
* **Storage:** ZFS (configured at install time).
* **Isolation Strategy:**
    * *Heavy/Insecure Workloads (Dev, User Compute):* **VMs** (Libvirt/KVM).
    * *Trusted Infrastructure (Media, DNS, Home Auto):* **NixOS Containers** (lightweight, declarative).

## Implementation Phases

### Phase 1: The Foundation
- [x] Boot `classic-laddie` with minimal Flake-based config.
- [x] Establish SSH access with declarative keys.
- [x] Format drives for ZFS.
- [x] Setup `home-manager` for the shared "Ergonomics" layer (Shell, Git, Keys).
- [x] Configure Tailscale for secure remote access.

### Phase 2: The Virtualization Host
- [x] **Priority:** Setup CI (GitHub Actions) to verify builds on push/PR.
- [x] Generate and commit `flake.lock`.
- [x] Enhance CI: Add formatting check (nixfmt) and expand build matrix.
- [x] Enable Virtualization (Libvirt/KVM) on `classic-laddie`.
- [x] Create a "Base Guest" module (shared config for all VMs).
- [x] Deploy first Dev VM (`johnny-walker`).
- [ ] Implement Secret Management (sops-nix/agenix) to secure passwords and keys.

### Phase 3: Services
- [ ] Deploy Media Stack (Jellyfin/Plex) in a NixOS Container.
- [ ] Deploy Home Automation (Home Assistant) in a Container/VM.

### Phase 4: Expansion
- [ ] Onboard other hardware (MacBooks).
- [x] Onboard NixOS VM (WSL2).