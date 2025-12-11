# Johnny Walker Setup Guide

This guide details the setup for the `johnny-walker` development environment. 
`johnny-walker` is a virtualized NixOS workstation running on the `classic-laddie` host.

## Architecture

- **Host**: `classic-laddie` (NixOS, KVM/Libvirt enabled)
- **Guest**: `johnny-walker` (NixOS, Standalone Flake Configuration)
- **Hypervisor**: QEMU/KVM via `virt-manager`

## Prerequisites

On `classic-laddie`, ensure that `libvirtd` is running.

```bash
# Verify libvirtd
systemctl status libvirtd
```

## Step 1: Build Disk Image

Instead of manually installing from ISO, we build a bootable QCOW2 image directly from the flake.

```bash
# Navigate to your cosmo clone
cd ~/hack/cosmo

# Build the image
nix build .#johnny-walker-image

# The result is a symlink 'result'. The actual file path is:
readlink -f result
# Example: /nix/store/...-nixos-image-25.05.../nixos.qcow2
```

## Step 2: Prepare Disk

Copy the built image to a persistent location. **Do not use the symlink directly** as it is read-only and will be garbage collected.

```bash
# Create directory
sudo mkdir -p /var/lib/libvirt/images

# Copy image (Rename it to johnny-walker.qcow2)
sudo cp $(readlink -f result) /var/lib/libvirt/images/johnny-walker.qcow2

# Set permissions
sudo chmod 644 /var/lib/libvirt/images/johnny-walker.qcow2
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/johnny-walker.qcow2
```

## Step 3: Create VM (virt-manager)

1.  Open **Virtual Machine Manager** (`virt-manager`).
2.  Click **Create New Virtual Machine**.
3.  **Step 1**: Choose "Import existing disk image".
4.  **Step 2**: 
    -   **Provide the existing storage path**: Browse to `/var/lib/libvirt/images/johnny-walker.qcow2`.
    -   **OS Type**: generic (or Linux 2024/latest).
5.  **Step 3**: Configure Resources:
    -   **Memory**: 20480 MB (20 GB)
    -   **CPUs**: 24
6.  **Step 4**: Name the VM `johnny-walker`.
    -   **Network Selection**: Select "Bridge device" -> `enp4s0` (or `virbr0`).
7.  Click **Finish**.

The VM should boot directly into the fully configured `johnny-walker` system.

## Post-Install

- Log in as `patrick` (password is set in the config, typically `nixos` or via keys).
- Resize the disk if necessary (the generated image might be small).
    ```bash
    # On Host:
    qemu-img resize /var/lib/libvirt/images/johnny-walker.qcow2 +50G
    
    # In Guest (after reboot):
    # NixOS should auto-expand if configured, or manually expand partition.
    ```
