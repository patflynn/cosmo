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
    * *Heavy/Insecure Workloads (Dev, User Compute):* **VMs** (MicroVMs or Libvirt).
    * *Trusted Infrastructure (Media, DNS, Home Auto):* **NixOS Containers** (lightweight, declarative).

## Implementation Phases

### Phase 1: The Foundation (Current)
- [x] Boot `classic-laddie` with minimal Flake-based config.
- [x] Establish SSH access with declarative keys.
- [x] Format drives for ZFS.
- [x] Setup `home-manager` for the shared "Ergonomics" layer (Shell, Git, Keys).
- [x] Configure Tailscale for secure remote access.

### Phase 2: The Virtualization Host
- [ ] **Priority:** Setup CI (GitHub Actions) to verify builds on push/PR.
- [ ] Enable Virtualization (Libvirt/KVM) on `classic-laddie`.
- [ ] Create a "Base Guest" module (shared config for all VMs).
- [ ] Deploy first Dev VM (`dev-patrick`).

### Phase 3: Services
- [ ] Deploy Media Stack (Jellyfin/Plex) in a NixOS Container.
- [ ] Deploy Home Automation (Home Assistant) in a Container/VM.

### Phase 4: Expansion
- [ ] Onboard other hardware (MacBooks, WSL) into the Flake.
