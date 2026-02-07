# Cosmo NixOS Configuration Review

**Date:** 2026-02-07
**Branch:** `feat/tailscale-exit-node`

## Executive Summary

Generally well-structured flake-based NixOS configuration with strong foundational practices (agenix secrets, flakes, home-manager integration, CI/CD). Several security and configuration issues identified below.

---

## High Priority Issues

### Security

#### 1. ~~Hard-coded UIDs Throughout Configuration~~ FIXED

**Files:**
- `modules/common/workstation.nix:101` - `XDG_RUNTIME_DIR = "/run/user/1000"`
- `modules/media-server/default.nix:191-192, 208-209` - `PUID = "1000"; PGID = "991"`

**Fix applied:** Now uses `config.users.users.patrick.uid` and `config.users.groups.media.gid`.

---

#### 2. ~~QEMU Running as Root~~ FIXED

**File:** `hosts/classic-laddie/default.nix:92`

**Fix applied:** Removed `runAsRoot = true`. GPU passthrough not in use; cgroup device allowlist retained.

---

#### 3. Media Services Open to Entire LAN - ACCEPTED RISK

**File:** `modules/media-server/default.nix:73-101`

**Status:** Intentional for family LAN access. Not a security concern for media content.

---

#### 4. Auto-Login Enabled - ACCEPTED RISK

**Files:**
- `hosts/classic-laddie/default.nix:79-82`
- `hosts/johnny-walker/default.nix:49-52`

**Status:** Required for headless Sunshine streaming. Physical security assumed.

---

#### 5. ~~Media VPN Secret Readable by Group~~ FIXED

**File:** `hosts/classic-laddie/default.nix:27-32`

**Fix applied:** Changed to `owner = "root"; group = "root"; mode = "0400"`. Container service runs as root.

---

### Configuration Bugs

#### 6. Hyprland Service Hard-coded Path - DEFERRED

**File:** `home/hyprland.nix:209`

**Status:** Path works currently. Lower priority refactor for later.

---

#### 7. ~~Shell Script Issues~~ FIXED

**File:** `home/scripts/sunshine-resolution.sh`

**Fix applied:**
- Added `set -euo pipefail`
- Replaced `ls` with `find` for safer filename handling
- Added error logging for systemctl commands

---

## Medium Priority Issues

### ~~Missing SSH Hardening~~ FIXED

**Files:** `hosts/classic-laddie/default.nix`, `hosts/makers-nix/default.nix`

**Fix applied:** Added `MaxAuthTries = 3`, `X11Forwarding = false`, `AllowAgentForwarding = false`, `PermitTunnel = false` to both hosts.

---

### Duplicate Home-Manager Config

**File:** `flake.nix:51-57, 71-77, 89-96`

Same configuration repeated three times. Extract to helper function:

```nix
let
  mkHomeManagerConfig = homeConfig: {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "backup";
    home-manager.extraSpecialArgs = { inherit inputs; };
    home-manager.users.patrick = import homeConfig;
  };
in
```

---

### Missing Service Dependencies

**File:** `modules/media-server/default.nix`

Media services have no explicit `after` or `requires` on ZFS mounts. If ZFS is slow to mount, services may fail.

```nix
systemd.services.plex = {
  after = [ "zfs-mount.service" ];
  requires = [ "zfs-mount.service" ];
};
```

---

### Loose Reverse Path Filtering

**File:** `modules/common/workstation.nix:94`

```nix
networking.firewall.checkReversePath = "loose";
```

Required for Tailscale but has security implications. Document why it's necessary.

---

### Inconsistent sudo Password Requirement

- `classic-laddie` sets `security.sudo.wheelNeedsPassword = true`
- `makers-nix` doesn't set this

---

## Low Priority / Documentation Gaps

### Missing Documentation

- Security model / threat model
- Backup strategy for ZFS
- Disaster recovery procedure
- Module dependency documentation
- Troubleshooting guide

### Module Consolidation Opportunities

Consider creating:
- `modules/common/ssh.nix` - consolidate SSH config
- `modules/common/nvidia.nix` - consolidate GPU config
- `modules/remote-access/tailscale.nix` - consolidate Tailscale config

### Unpinned Input

**File:** `flake.nix`

```nix
nixos-wsl.url = "github:nix-community/NixOS-WSL/main";  # "main" is unpinned
```

---

## Strengths

- Well-structured flake with clear module separation
- Good CI/CD pipeline (format, build, flake check, zizmor security scanning)
- Proper secrets management with agenix
- Immutable users (`mutableUsers = false`) - security-first approach
- Tailscale integration with proper firewall rules
- ZFS storage with modern configuration
- Comprehensive AGENTS.md documentation

---

## Recommended Priority Actions

### This Week
- [x] Fix hard-coded `/run/user/1000` in workstation.nix
- [x] Fix hard-coded `PUID=1000;PGID=991` in media-server
- [x] Remove unnecessary `runAsRoot = true` from QEMU config
- [x] Tighten VPN secret permissions to root-only
- [x] Add error handling to sunshine-resolution.sh script
- [x] Add SSH hardening options (MaxAuthTries, X11Forwarding, etc.)
- [ ] Document security implications of auto-login

### This Month
- [ ] Create `modules/common/ssh.nix` to consolidate SSH config
- [ ] Add assertions to media-server module checking prerequisites
- [ ] Review and tighten media server firewall rules
- [ ] Fix Hyprland service unit path issues

### This Quarter
- [ ] Create comprehensive troubleshooting guide
- [ ] Implement backup/recovery documentation
- [ ] Add proper error handling to shell scripts
- [ ] Consider restricting QEMU from running as root
