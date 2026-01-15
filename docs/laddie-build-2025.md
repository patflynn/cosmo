# Server Rebuild Log (December 2025)

This document records the steps taken to "nuke and pave" `classic-laddie` with a fresh ZFS-based NixOS installation, starting from a situation where physical USB access was unavailable.

## 1. The Challenge
* **Goal:** Fresh NixOS install with ZFS on root (`rpool`) and data (`tank`).
* **Constraint:** Lost physical USB installer key.
* **Hardware:**
    * `nvme0n1` (1TB NVMe): OS Drive
    * `sda` (4TB SATA): Storage Drive
    * Network: UniFi UDM Pro + Windows Desktop

## 2. Boot Method: "PXE Rescue"
Since we couldn't use a USB stick, we used a Windows desktop to serve a bootloader over the network.

### Windows Host Setup
1.  Downloaded [Tftpd64 (Portable)](https://github.com/tftpd64/tftpd64).
2.  Downloaded [netboot.xyz.efi](https://netboot.xyz/downloads/) and renamed it to `boot.efi`.
3.  Placed `boot.efi` in a folder on the Desktop (e.g., `C:\Users\Pat\Desktop\PXE`).
4.  Configured Tftpd64:
    * **TFTP Server:** Enabled. Root dir set to the `PXE` folder.
    * **DHCP Server:** **DISABLED** (We used the UDM Pro for DHCP).

### Router (UDM Pro) Setup
1.  Navigated to **Settings -> Networks -> Default**.
2.  Enabled **Advanced -> Network Boot**.
3.  **Server:** IP of the Windows Desktop (e.g., `192.168.1.50`).
4.  **Filename:** `boot.efi`.

### Booting
1.  Booted `classic-laddie` and selected "UEFI: Network Boot" (F11/F12).
2.  Loaded `netboot.xyz` -> Linux Network Installs -> NixOS -> 24.11.

---

## 3. Storage Configuration (ZFS)
Once the installer shell (`[root@nixos:~]#`) was live, we partitioned the drives.

### Disk Cleanup
```bash
wipefs -a /dev/nvme0n1
wipefs -a /dev/sda

## partioning
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1024MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 1024MB 100%
mkfs.vfat -n BOOT /dev/nvme0n1p1

## ZFS pool creation
# OS Pool
zpool create -O mountpoint=legacy -O atime=off -O compression=lz4 -O xattr=sa -O acltype=posix rpool /dev/nvme0n1p2

# Storage Pool (Whole Disk)
zpool create -O mountpoint=legacy -O atime=off -O compression=lz4 -O xattr=sa -O acltype=posix tank /dev/sda

# dataset creation
# OS Datasets
zfs create rpool/root
zfs snapshot rpool/root@blank
zfs create rpool/nix
zfs create rpool/home

# Swap (16GB for large builds like CUDA/Android Studio)
zfs create -V 16G -o compression=off -o sync=always -o primarycache=none rpool/swap
mkswap -f /dev/zvol/rpool/swap

# Storage Datasets
zfs create tank/media
zfs create tank/personal

# mount before install
mount -t zfs rpool/root /mnt
mkdir -p /mnt/{nix,home,boot}

mount -t zfs rpool/nix /mnt/nix
mount -t zfs rpool/home /mnt/home
mount /dev/nvme0n1p1 /mnt/boot

# NOTE: We do NOT mount tank/* datasets here to prevent nixos-generate-config 
# from adding them to hardware-configuration.nix. They are manually defined in default.nix.

# generate hardware config
nixos-generate-config --root /mnt

# Add static but arbirtrary hostid to laddie's default.nix because nixos and zfs
networking.hostId = "8425e349"; # Example ID

# install
nixos-install --no-write-lock-file --flake github:patflynn/cosmo#classic-laddie



