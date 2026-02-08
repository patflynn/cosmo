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

## 5. Installation Steps

### 5.1 Boot NixOS Installer via PXE

1. Boot the machine and press F11/F12 for boot menu
2. Select "UEFI: Network Boot" or similar
3. netboot.xyz will load → select Linux Network Installs → NixOS
4. Connect to network (should already be connected via PXE)

### 5.2 Partition Disk 1 (Seagate)

```bash
# Identify disks
lsblk
# Disk 1 should be /dev/nvme1n1 (the 2TB Seagate)

# Wipe existing partitions
wipefs -a /dev/nvme1n1

# Create GPT partition table
parted /dev/nvme1n1 -- mklabel gpt

# Create EFI partition (1GB)
parted /dev/nvme1n1 -- mkpart ESP fat32 1MB 1024MB
parted /dev/nvme1n1 -- set 1 esp on

# Create LUKS partition (rest of disk)
parted /dev/nvme1n1 -- mkpart primary 1024MB 100%

# Format EFI partition
mkfs.vfat -F32 -n NIXBOOT /dev/nvme1n1p1
```

### 5.3 Setup LUKS Encryption

```bash
# Create encrypted container
cryptsetup luksFormat --type luks2 /dev/nvme1n1p2

# Open the encrypted container
cryptsetup open /dev/nvme1n1p2 cryptroot
```

### 5.4 Create Btrfs Filesystem with Subvolumes

```bash
# Create Btrfs filesystem
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# Mount and create subvolumes
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@swap
umount /mnt

# Mount subvolumes with compression
mount -o subvol=@root,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,swap,boot}
mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@swap,noatime /dev/mapper/cryptroot /mnt/swap
mount /dev/nvme1n1p1 /mnt/boot

# Create swapfile (16GB)
btrfs filesystem mkswapfile --size 16g /mnt/swap/swapfile
swapon /mnt/swap/swapfile
```

### 5.5 Generate Hardware Configuration

```bash
nixos-generate-config --root /mnt
```

This creates `/mnt/etc/nixos/hardware-configuration.nix` which we'll copy to the repo.

### 5.6 Install NixOS

```bash
# Install git and clone the repo
nix-shell -p git

# Clone cosmo repo
git clone https://github.com/patflynn/cosmo /mnt/etc/nixos/cosmo

# Copy generated hardware config to repo
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/cosmo/hosts/weller/

# Install NixOS
nixos-install --no-write-lock-file --flake /mnt/etc/nixos/cosmo#weller
```

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
- LUKS encryption setup
- Btrfs mount options
- NVIDIA driver configuration
- Workstation profile (Hyprland, Steam, Sunshine)

### 7.2 `hosts/weller/hardware-configuration.nix`

Placeholder - regenerate during installation with actual UUIDs.

### 7.3 `flake.nix`

`weller` added to nixosConfigurations.

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
