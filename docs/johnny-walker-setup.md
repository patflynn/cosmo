# Johnny Walker Setup Guide

This guide details the manual steps required to set up the `johnny-walker` development environment. 
`johnny-walker` is a virtualized NixOS workstation running on the `classic-laddie` host.

## Architecture

- **Host**: `classic-laddie` (NixOS, KVM/Libvirt enabled)
- **Guest**: `johnny-walker` (NixOS, Standalone Flake Configuration)
- **Hypervisor**: QEMU/KVM via `virt-manager`

## Prerequisites

On `classic-laddie`, ensure that `libvirtd` is running and you have the NixOS installation ISO.

```bash
# Verify libvirtd
systemctl status libvirtd

# Download NixOS Minimal ISO (if not already present)
wget https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso
```

## VM Creation Steps (virt-manager)

1.  Open **Virtual Machine Manager** (`virt-manager`).
2.  Click **Create New Virtual Machine**.
3.  **Step 1**: Choose "Local install media (ISO image or CDROM)".
4.  **Step 2**: Browse and select the downloaded NixOS ISO.
5.  **Step 3**: Configure Resources (Recommended based on previous MicroVM config):
    -   **Memory**: 20480 MB (20 GB)
    -   **CPUs**: 24
6.  **Step 4**: Create Disk Image.
    -   Size: ~50GB+ (or as needed for development).
7.  **Step 5**: Name the VM `johnny-walker`.
    -   **Network Selection**: Select "Bridge device" -> `enp4s0` (or `virbr0` for NAT if bridging is not desired/available).
8.  Click **Finish** to boot the VM.

## Installation Procedure

Once the VM boots into the NixOS installer:

### 1. Partition & Format
The `hardware-configuration.nix` expects specific disk labels (`nixos` and `boot`).

```bash
# Switch to root
sudo -i

# Identify disk (usually /dev/vda)
lsblk

# Partition (Example using parted)
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart ESP fat32 1MB 512MB
parted /dev/vda -- set 1 esp on
parted /dev/vda -- mkpart primary ext4 512MB 100%

# Format
mkfs.fat -F 32 -n boot /dev/vda1
mkfs.ext4 -L nixos /dev/vda2

# Mount
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

### 2. Clone Configuration
Clone the repository to the new system.

```bash
# Install git (if strictly minimal ISO)
nix-env -iA nixos.git

# Clone repo
git clone https://github.com/patflynn/cosmo /mnt/etc/nixos
```

### 3. Install
Install the `johnny-walker` flake configuration.

```bash
cd /mnt/etc/nixos
nixos-install --flake .#johnny-walker
```

### 4. Finalize
Set the root password if desired (though user `patrick` is configured with keys/password in the flake).

```bash
reboot
```

After rebooting, remove the ISO from the VM settings in `virt-manager` if it didn't eject automatically.

## Post-Install

- Log in as `patrick`.
- Verify network connectivity.
- Verify that you can rebuild the system from within the VM:
    ```bash
    sudo nixos-rebuild switch --flake ~/hack/cosmo
    ```
