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
├── EFI System Partition (1GB) - GRUB bootloader
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
- GRUB on Disk 1 can chainload Windows from Disk 0

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

### 4.2 Create NixOS Installation USB

```bash
# Download NixOS minimal ISO
wget https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso

# Write to USB (replace sdX with your USB device)
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress
```

### 4.3 Note Windows Boot Manager Location

The Windows Boot Manager lives on Disk 0's EFI partition. We'll configure GRUB to chainload it.

---

## 5. Installation Steps

### 5.1 Boot NixOS Installer

1. Insert USB and boot the machine
2. Enter BIOS (F2/Del) and set USB as first boot device
3. Boot into NixOS installer
4. Connect to network (ethernet recommended)

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

### 5.7 Configure GRUB for Dual-Boot

After first boot into NixOS, GRUB should auto-detect Windows. If not:

```bash
# Find Windows EFI partition UUID
sudo blkid | grep -i windows

# Regenerate GRUB config
sudo nixos-rebuild switch
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

1. Reboot and verify GRUB menu shows both NixOS and Windows
2. Boot into Windows and confirm it still works
3. Boot into NixOS and confirm everything works

---

## 7. NixOS Configuration

The following files are in the cosmo repo:

### 7.1 `hosts/weller/default.nix`

Configuration includes:
- GRUB bootloader with os-prober for Windows detection
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

**Default behavior:** GRUB will show a menu on boot with:
- NixOS (weller) - default, 5 second timeout
- Windows Boot Manager (makers-mark)

To change default or timeout, modify GRUB settings in the NixOS configuration.

---

## 9. Encryption Notes

- **NixOS (weller):** LUKS2 encryption with passphrase on boot
- **Windows (makers-mark):** Consider enabling BitLocker for parity (optional)
- **Future:** Could add TPM unlock for automatic decryption

---

## 10. Troubleshooting

### Windows not detected by GRUB
```bash
# Ensure os-prober is enabled and can see Windows EFI
sudo os-prober
# Should output something like:
# /dev/nvme0n1p1@/EFI/Microsoft/Boot/bootmgfw.efi:Windows Boot Manager:Windows:efi

# Rebuild NixOS to regenerate GRUB config
sudo nixos-rebuild switch
```

### Can't boot Windows after NixOS install
1. Enter BIOS and change boot order to prioritize Disk 0
2. Or use BIOS boot menu (F11/F12) to select Windows Boot Manager

### LUKS password prompt not appearing
Ensure `boot.initrd.luks.devices` is correctly configured in hardware-configuration.nix.
