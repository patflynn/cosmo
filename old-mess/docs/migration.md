# Migration Guide

This document outlines the step-by-step process for migrating from the old configuration structure to the new unified cross-platform structure.

## Phase 1: Consolidation (Current Phase)

### Step 1: Create Modular Structure

- [x] Create common modules for shared functionality
- [x] Create host-specific modules
- [x] Reorganize home-manager configurations

### Step 2: Migrate Existing Systems

1. **Desktop (classic-laddie)**:
   - [ ] Copy hardware-configuration.nix from classic-laddie to modules/hosts/desktop/
   - [ ] Test with `sudo nixos-rebuild test --flake .#desktop`
   - [ ] Switch with `sudo nixos-rebuild switch --flake .#desktop`

2. **Server (nix-basic)**:
   - [ ] Copy hardware-configuration.nix from nix-basic to modules/hosts/server/
   - [ ] Test with `sudo nixos-rebuild test --flake .#server`
   - [ ] Switch with `sudo nixos-rebuild switch --flake .#server`

## Phase 2: Cross-Platform Support

### Step 1: Setup Darwin Support

- [x] Add nix-darwin to flake inputs
- [x] Create basic darwin configuration
- [ ] Test on macOS with `darwin-rebuild test --flake .#macbook`

### Step 2: Setup ChromeOS Support

- [x] Add standalone home-manager configuration
- [ ] Test on ChromeOS with `home-manager test --flake .#chromeos`

## Phase 3: Modernization

### Step 1: Update Dependencies

- [ ] Run `nix flake update` to get latest versions
- [ ] Fix any incompatibilities
- [ ] Test all configurations

### Step 2: Improve Module Structure

- [ ] Extract specific services into their own modules
- [ ] Create better documentation for each module
- [ ] Implement option typing and assertions for safer configs

## Phase 4: Documentation and CI

### Step 1: Complete Documentation

- [x] Create basic documentation
- [ ] Document each module
- [ ] Add examples for common tasks

### Step 2: Enhance CI/CD

- [x] Add basic GitHub Actions workflows
- [ ] Add matrix testing for different platforms
- [ ] Implement automatic deployment testing