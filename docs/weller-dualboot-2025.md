# Weller Dual-Boot Setup (February 2025)

This document records the plan and steps for setting up a dual-boot Windows 11 + NixOS on the makers-mark hardware.

## Hostname Scheme

| Environment | Hostname | Purpose |
|-------------|----------|---------|
| Windows 11 | `makers-mark` | Windows-only games (iRacing, BF6) |
| WSL2 NixOS | `makers-nix` | Existing WSL environment |
| Native NixOS | `weller` | Daily driver, development, Linux gaming |

## 1. Hardware

| Component | Details |
|-----------|---------|
| **CPU** | AMD Ryzen 9 5950X (16-core) |
| **GPU** | NVIDIA RTX 4090 |
| **RAM** | 16GB+ |
| **Disk 0** | Samsung 970 NVMe (932GB) - Windows (makers-mark) |
| **Disk 1** | Seagate FireCuda 510 NVMe (1.86TB) - NixOS (weller) |

## 2. Disk Layout Decision

**Chosen approach:** Each OS gets its own NVMe drive.

```
Disk 0 (Samsung 970 - 932GB):
├── EFI System Partition (~100MB) - Windows bootloader
├── Microsoft Reserved (16MB)
├── Windows C: (~930GB) - Windows 11 + Windows games
└── Recovery partitions

Disk 1 (Seagate FireCuda - 1.86TB):
├── EFI System Partition (1GB) - systemd-boot
└── LUKS encrypted partition (~1.85TB)
    └── Btrfs with subvolumes:
        ├── @root     (NixOS /)
        ├── @home     (/home)
        ├── @nix      (/nix)
        └── @swap     (swapfile)
```

**Rationale:**
- Clean separation between OSes
- Both drives are NVMe (no performance difference)
- Full disk encryption for NixOS
- Windows keeps its current disk unchanged
- Use UEFI boot menu (F11/F12) to switch between OSes

## 3. Use Cases

| OS | Purpose |
|----|---------|
| **Windows 11 (makers-mark)** | iRacing, Battlefield 6, Windows-only games |
| **NixOS (weller)** | Development, Linux gaming, media consumption, daily driver |

## 4. Pre-Installation Tasks

### 4.1 Backup D: Drive to classic-laddie

D: drive contents (~917GB):

| Folder | Size | Notes |
|--------|------|-------|
| SteamLibrary | 458 GB | Games (re-downloadable but faster to restore) |
| genes | 142 GB | **Irreplaceable** - genealogy data |
| Epic Games | 141 GB | Games (re-downloadable) |
| star citizen | 103 GB | Game (slow to re-download) |
| iracing cars tracks backup | 73 GB | **Custom content** |
| mb_bios_x570-aorus-pro_f35d | 0.02 GB | BIOS backup |

**Backup command:**
```bash
# Create backup dataset on classic-laddie
ssh classic-laddie "sudo zfs create tank/personal/weller-backup"

# Backup entire D: drive (~917GB, ~1.5 hours over 2.5Gbps LAN)
rsync -avhP --info=progress2 /mnt/d/ classic-laddie:/tank/personal/weller-backup/
```

### 4.2 PXE Boot Setup

Using classic-laddie as PXE server (see PR #229):

```bash
# On classic-laddie: download netboot.xyz
sudo curl -L https://boot.netboot.xyz/ipxe/netboot.xyz.efi -o /srv/tftp/netboot.xyz.efi
```

Configure UDM Pro:
1. Settings → Networks → Default → Advanced → Network Boot
2. Server: `192.168.1.28` (classic-laddie)
3. Filename: `netboot.xyz.efi`

---

## 5. Installation Steps (Two-Stage Process)

To avoid "chicken-and-egg" problems with secrets (`agenix`) and SSH keys, we use a two-stage installation process.

### 5.1 Stage 1: Bootstrap Install

The first stage installs a minimal system with:
- **Mutable users** (allows setting/changing passwords)
- **SSH enabled** with password authentication
- **No secrets/agenix** (prevents decryption errors on first boot)

1. **Boot NixOS Installer via PXE**
   - Boot the machine and press F11/F12 for boot menu
   - Select "UEFI: Network Boot" or similar
   - netboot.xyz will load → select Linux Network Installs → NixOS

2. **Partition and Format with Disko**
   ```bash
   # Clone cosmo repo
   nix-shell -p git
   git clone https://github.com/patflynn/cosmo /tmp/cosmo
   cd /tmp/cosmo

   # Run disko to partition, encrypt, and mount
   # This will prompt for the LUKS encryption password
   sudo nix --experimental-features "nix-command flakes" \
     run github:nix-community/disko -- \
     --mode disko ./hosts/weller/disk-config.nix
   ```

3. **Install the Bootstrap Configuration**
   ```bash
   # Install using the weller-bootstrap target
   nixos-install --no-write-lock-file --flake /tmp/cosmo#weller-bootstrap
   ```

4. **Reboot and Access via SSH**
   - Reboot into the new system.
   - From your laptop, log in as `root` (using your SSH keys):
     ```bash
     ssh root@weller-bootstrap
     ```
   - No initial password is required as your keys from `secrets/keys.nix` are pre-authorized in the bootstrap image.
   - For better security, password authentication is disabled by default.

### 5.2 Stage 2: Full Configuration

Once the bootstrap system is running, we can finalize the setup.

1. **Generate Host SSH Key**
   ```bash
   # The host key is usually at /etc/ssh/ssh_host_ed25519_key.pub
   cat /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. **Update Repository Secrets (on your laptop)**
   - Copy the new host key to `secrets/keys.nix`.
   - Rekey secrets: `agenix -r`.
   - Commit and push changes to GitHub.

3. **Apply Full Configuration (on weller)**
   ```bash
   cd ~/hack/cosmo # or wherever you keep the repo
   git pull
   sudo nixos-rebuild switch --flake .#weller
   ```

The system will now have:
- Immutable users (managed by Nix)
- Secrets decrypted via `agenix`
- Full workstation environment (NVIDIA, Hyprland, etc.)

---

## 6. Post-Installation

### 6.1 Restore Data from Backup

```bash
# Restore games and data from classic-laddie
rsync -avhP classic-laddie:/tank/personal/weller-backup/ ~/restored-backup/

# Move Steam library to appropriate location
# Move personal data (genes, iracing backup) to /home
```

### 6.2 Enroll in Tailscale

```bash
sudo tailscale up
```

### 6.3 Verify Dual-Boot

1. Reboot - NixOS should boot via systemd-boot
2. Use UEFI boot menu (F11/F12) to boot Windows and confirm it works
3. Optionally set default boot order in BIOS

---

## 7. NixOS Configuration

The following files are in the cosmo repo:

### 7.1 `hosts/weller/default.nix`

Configuration includes:
- systemd-boot bootloader
- Hardware settings (kernel modules, AMD microcode)
- NVIDIA driver configuration
- Workstation profile (Hyprland, Steam, Sunshine)

### 7.2 `hosts/weller/disk-config.nix`

Disko declarative disk configuration:
- 1GB EFI partition
- LUKS2 encrypted root with Btrfs
- Subvolumes: @root, @home, @nix, @swap
- 16GB swapfile

### 7.3 `flake.nix`

- `weller` added to nixosConfigurations
- `disko` input added for declarative partitioning

### 7.4 `secrets/keys.nix`

Host SSH key will be added after first boot.

---

## 8. Boot Selection

**Default behavior:** Each disk has its own bootloader:
- Disk 0: Windows Boot Manager (makers-mark)
- Disk 1: systemd-boot (weller)

**To switch OSes:** Use UEFI boot menu (F11/F12) or set boot order in BIOS.

---

## 9. Encryption Notes

- **NixOS (weller):** LUKS2 encryption with passphrase on boot
- **Windows (makers-mark):** Consider enabling BitLocker for parity (optional)
- **Future:** Could add TPM unlock for automatic decryption

---

## 10. Troubleshooting

### Can't boot Windows after NixOS install
1. Use UEFI boot menu (F11/F12) to select Windows Boot Manager
2. Or enter BIOS and change boot order to prioritize Disk 0

### Can't boot NixOS
1. Use UEFI boot menu (F11/F12) to select the Seagate drive
2. Or enter BIOS and change boot order to prioritize Disk 1

### LUKS password prompt not appearing
Ensure `boot.initrd.luks.devices` is correctly configured in hardware-configuration.nix.
